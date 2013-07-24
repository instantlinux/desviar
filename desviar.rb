# Desviar - URL redirection for security applications
#
# Created 14 Jul 2013
#
#   Copyright 2013 Richard Braun
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0

require 'sinatra/base'
require 'securerandom'
require 'dm-core'
require 'dm-migrations'
require 'dm-validations'
require 'dm-timestamps'
require 'syntaxi'
require 'net/http'
require 'test/unit'
require 'rack/test'
require 'rack/recaptcha'
# require 'webrick/httpauth/htpasswd'

class Desviar < Sinatra::Base

  require File.expand_path '../lib/model.rb', __FILE__
  require File.expand_path '../lib/encrypt.rb', __FILE__

# Auth parsing is work-in-progress
#  require File.expand_path '../lib/auth.rb', __FILE__

  configure do
    require File.expand_path '../config/config.rb', __FILE__

    DataMapper::Logger.new($stdout, :debug) if $config[:debug]
    DataMapper.setup(:default, $config[:dbmethod])
    DataMapper.auto_upgrade! if DataMapper.respond_to?(:auto_upgrade!)
  end

  get '/' do
    redirect '/create'
  end
  
  # create
  get '/create' do
    erb :create
  end
  
  # submit
  post '/create' do
    @desviar = Desviar::Data.new(
       :redir_uri      => params[:desviar_redir_uri],
       :notes          => params[:desviar_notes],
       :expiration     => params[:desviar_expiration],
       :temp_uri       => "#{$config[:uriprefix]}#{SecureRandom.urlsafe_base64($config[:hashlength])[0,$config[:hashlength]]}#{$config[:urisuffix]}",
       :expires_at     => Time.now + params[:desviar_expiration].to_i,
       :captcha        => params[:desviar_captcha],
       :captcha_prompt => params[:desviar_captchaprompt],
       :captcha_button => params[:desviar_captchabutton],
       :captcha_validated => false)

    # Cache the remote URI
    object = URI.parse(@desviar[:redir_uri])
    http = Net::HTTP.new(object.host, object.port)
    http.use_ssl = @desviar[:redir_uri].index('https') == 0
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    req = Net::HTTP::Get.new(object.request_uri)
    if params[:desviar_remoteuser] != ''
      req.basic_auth params[:desviar_remoteuser], params[:desviar_remotepw]
    end
    response = http.request(req)
    if $config[:dbencrypt].nil?
      @desviar[:content] = response.body
    else
      obj = Desviar::EncryptedItem::Encryptor.new(response.body, $config[:cryptkey])
      @desviar[:content] = obj.encrypted_data
      @desviar[:hmac] = obj.hmac
      @desviar[:cipher_iv] = obj.iv
    end
  
    # Insert the new record and display the new link
    if @desviar.save
      redirect "/link/#{@desviar.id}"
    else
      error 400
    end
  end
  
  # show link ID
  get '/link/:id' do
    @desviar = Desviar::Data.get(params[:id])
    if @desviar && DateTime.now < @desviar[:expires_at]
      erb :show
    else
      error 404
    end
  end

  # clean out expired records
  get '/clean' do
    # TODO: figure out the clean "native" way of DataMapper::Collection.destroy
    #   - but this works fine for small databases
    @desviar = DataMapper.repository(:default).adapter
    @records = Desviar::Data.all(:expires_at.lt => DateTime.now)
    @records.each do |item|
      @desviar.execute("DELETE FROM desviar_data WHERE id=#{item.id};")
    end
    redirect "/list"
  end

  # list of most recent records
  get '/list' do
    @desviar = Desviar::Data.all(:limit => $config[:recordsmax], :order => [ :created_at.desc ])
    @total = @desviar.length
    @count = [ @total, $config[:recordsmax] ].min
    erb :list
  end

  def self.new(*)
    app = Rack::Auth::Digest::MD5.new(super) do |username|
      {'desviar' => $config[:adminpw]}[username]
    end
    app.realm  = $config[:authprompt]
    app.opaque = $config[:authsalt]
    app
  end
end

#############################################
# Class Desviar::Public - routes without auth

class Desviar::Public < Sinatra::Base

  configure do
    use Rack::Recaptcha, :public_key => $config[:captchapub], :private_key => $config[:captchapriv]
    helpers Rack::Recaptcha::Helpers
  end

  # display content
  get '/:temp_uri' do
    @desviar = Desviar::Data.first(:temp_uri => params[:temp_uri])
    cache_control :public, :max_age => 30
    if @desviar && DateTime.now < @desviar[:expires_at]
      if $config[:dbencrypt].nil?
        @content = @desviar[:content]
      else
        obj = Desviar::EncryptedItem::Decryptor::for({
            'cipher'         => $config[:dbencrypt], 
            'version'        => 2, 
            'encrypted_data' => @desviar[:content],
            'iv'             => Base64.encode64(@desviar[:cipher_iv]),
            'hmac'           => @desviar[:hmac]}, $config[:cryptkey])
        puts "hmac=#{@desviar[:hmac]}\n"
        puts "iv=#{@desviar[:cipher_iv]}\n"
        @content = obj.decrypted_data

      end
      if !@desviar[:captcha]
        erb :content
      elsif @desviar[:captcha_validated]
        @desviar[:captcha_validated] = false
        @desviar.save
        erb :content
      else 
        @button = @desviar[:captcha_button]
        erb :captcha
      end
    else
      error 404
    end
  end

  # handle reCAPTCHA
  post '/:temp_uri' do
    if recaptcha_valid?
      @desviar = Desviar::Data.first(:temp_uri => params[:temp_uri])
      @desviar[:captcha_validated] = true
      @desviar.save
    end
    redirect "/desviar/#{params[:temp_uri]}"
  end
end

# TODO - switch to MiniTest, move to test subdir
class DesviarTest <Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Desviar
  end
 
  def test_list
    get '/list'
    assert last_response.ok?
  end
end
