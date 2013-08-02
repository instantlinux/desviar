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
require 'sinatra/json'
require 'securerandom'
require 'dm-core'
require 'dm-migrations'
require 'dm-validations'
require 'dm-timestamps'
require 'syntaxi'
require 'syslog'
require 'net/http'
#require 'test/unit'
require 'rack/test'
require 'rack/recaptcha'
require 'multi_json'

if ENV['DESVIAR_CONFIG']
  require ENV['DESVIAR_CONFIG']
else
  require File.expand_path '../../config/config', __FILE__
end
require File.expand_path '../version', __FILE__
require File.expand_path '../encrypt', __FILE__
require File.expand_path '../model', __FILE__
# Auth parsing is work-in-progress
# require File.expand_path '../auth', __FILE__

module Desviar
  class Authorized < Sinatra::Base

    configure do
      DataMapper::Logger.new($stdout, :debug) if $config[:debug]
      DataMapper.setup(:default, $config[:dbmethod])
      DataMapper.auto_upgrade! if DataMapper.respond_to?(:auto_upgrade!)
      $config[:cryptkey] = SecureRandom.base64(32) if $config[:cryptkey].nil?
      helpers Sinatra::JSON
    end

    get '/' do
      redirect '/create'
    end
  
    # create
    get '/create' do
      puts request.env.inspect if $config[:debug]
      erb :create
    end
  
    # submit
    post '/create' do
      error 400 if params[:redir_uri].strip == ""

      # Create a new data record, generating the random URI and omitting
      #   remote-access credentials if specified.
      @desviar = Desviar::Model::Main.new(params.merge({
        :temp_uri => "#{$config[:uriprefix]}#{SecureRandom.urlsafe_base64($config[:hashlength])[0,$config[:hashlength]]}#{$config[:urisuffix]}",
        :expires_at     => Time.now + params[:expiration].to_i,
        :captcha_validated => false
      }).delete_if {|key, val| key == "redir_uri" || key == "remoteuser" || key == "remotepw"})

      # Cache the remote URI
      object = URI.parse(params[:redir_uri])
      http = Net::HTTP.new(object.host, object.port)
      http.use_ssl = params[:redir_uri].index('https') == 0
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      req = Net::HTTP::Get.new(object.request_uri)
      req.basic_auth params[:remoteuser], params[:remotepw] if params[:remoteuser] != ''
      response = http.request(req)
      if !$config[:dbencrypt]
        @desviar[:content] = response.body[0, $config[:contentmax]]
      else
        obj = Desviar::EncryptedItem::Encryptor.new(
                  response.body[0, $config[:contentmax]], $config[:cryptkey])
        @desviar[:content]   = obj.encrypted_data
        @desviar[:hmac]      = obj.hmac
        @desviar[:cipher_iv] = obj.iv
      end

      @desviar[:redir_uri] = $config[:redir_retain] == "keep" ? params[:redir_uri] : ""

      # Insert the new record and display the new link
      if @desviar.save
        Desviar::Public::log "Created #{@desviar.id} #{@desviar.redir_uri} #{@desviar.expires_at} #{request.ip}"
        redirect "/link/#{@desviar.id}"
      else
        error 400
      end
    end
  
    # show link ID
    get '/link/:id' do
      @desviar = Desviar::Model::Main.get(params[:id])
      if @desviar && DateTime.now < @desviar[:expires_at]
        erb :show
      else
        error 404
      end
    end

    # show link info - json format
    get '/link/json/:id' do
      @desviar = Desviar::Model::Main.get(params[:id])
      if @desviar && DateTime.now < @desviar[:expires_at]
        json @desviar.attributes.delete_if {|key, val| key == :content || key == :cipher_iv || key == :hmac}
      else
        error 404
      end
    end

    # clean out expired records
    get '/clean' do
      # TODO: figure out the clean "native" way of DataMapper::Collection.destroy
      #   - but this works fine for small databases
      @desviar = DataMapper.repository(:default).adapter
      @records = Desviar::Model::Main.all(:expires_at.lt => DateTime.now,
                                          :fields => [ :id ])
      Desviar::Public::log "debug cleanup found #{@records.length}"
      count = @records.length
      @records.each do |item|
        @desviar.execute("DELETE FROM desviar_model_mains WHERE id=#{item.id};")
      end
      Desviar::Public::log "Cleaned #{count} records" if count != 0
      redirect "/list"
    end

    # list of most recent records
    get '/list' do
      @desviar = Desviar::Model::Main.all(
         :limit => $config[:recordsmax],
         :order => [ :created_at.desc ],
         :fields => [ :id, :created_at, :expires_at, :redir_uri, :captcha, :notes ])
      @total = @desviar.length
      @count = [ @total, $config[:recordsmax] ].min
      erb :list
    end

    # list - json
    get '/list/json' do
      @desviar = Desviar::Model::Main.all(
         :limit => $config[:recordsmax],
         :order => [ :created_at.desc ],
         :fields => [ :id, :redir_uri, :temp_uri, :expiration, :captcha,
                      :notes, :owner, :created_at, :expires_at ])
      list = Array.new
      @desviar.each do |item|
        list << {
          :id => item.id, :redir_uri => item.redir_uri,
          :temp_uri => item.temp_uri, :expiration => item.expiration,
          :captcha => item.captcha, :notes => item.notes,
          :owner => item.owner, :created_at => item.created_at,
          :expires_at => item.expires_at }
      end
      json list
    end

    # configuration
    get '/config' do
      erb :config
    end

    # configuration - json
    get '/config/json' do
      json $config.reject { |opt, val| 
          opt.to_s.index('msg_') == 0 ||
          $config[:hidden].include?(opt.to_s) ||
          $config[:hashed].include?(opt.to_s)
      }
    end

    # submit
    post '/config' do
      params['config'].each do |opt, val|
        if $config[opt.to_sym].class == Fixnum
          $config[opt.to_sym] = val.to_i
        elsif val != "" || !$config[:hashed].include?(opt)
          $config[opt.to_sym] = case val
            when "true" then true
            when "false" then false
            when "nil" then nil
            else val
            end
        end
      end

      DataMapper::Logger.new($stdout, :debug) if $config[:debug]
      $config[:cryptkey] = SecureRandom.base64(32) if $config[:cryptkey].nil?

      puts $config.inspect if $config[:debug]
      Desviar::Public::log "Configuration updated"
      redirect "/list"
    end

    def self.new(*)
  #   TODO: htpasswd parsing
  #   Desviar::Auth::authenticate!
  #   @auth.call()
      app = Rack::Auth::Digest::MD5.new(super) do |username|
        {$config[:adminuser] => $config[:adminpw]}[username]
      end
      app.realm  = $config[:authprompt]
      app.opaque = $config[:authsalt]
      app
    end

=begin
  class Mytest
    def initialize(app)
#      Desviar::Public::log "Initializing auth from .htpasswd"
      @obj = Rack::Auth::Basic.new(app) do |username, password|
        unless File.exist?('../config/.htpasswd')
          raise PasswordFileNotFound.new("#{file} is not found. Please create it with htpasswd")
        end
        htpasswd = WEBrick::HTTPAuth::Htpasswd.new(file)
        crypted = htpasswd.get_passwd(nil, user, false)
        crypted == pass.crypt(crypted) if crypted
      end
    end
  end
=end

  end

  #############################################
  # Class Desviar::Public - routes without auth

  class Public < Sinatra::Base

    configure do
      use Rack::Recaptcha, :public_key => $config[:captchapub], :private_key => $config[:captchapriv]
      helpers Rack::Recaptcha::Helpers
    end

    # display content
    get '/:temp_uri' do
      @desviar = Desviar::Model::Main.first(:temp_uri => params[:temp_uri])
      cache_control :public, :max_age => 30
      if @desviar && DateTime.now < @desviar[:expires_at]
        if @desviar[:captcha] && !@desviar[:captcha_validated]
          @button = @desviar[:captcha_button]
          erb :captcha
        else
          @desviar.update(:captcha_validated => false) if @desviar[:captcha_validated]
          if !$config[:dbencrypt]
            @content = @desviar[:content]
          else
            obj = Desviar::EncryptedItem::Decryptor::for({
                'cipher'         => $config[:dbencrypt], 
                'version'        => 2, 
                'encrypted_data' => @desviar[:content],
                'iv'             => Base64.encode64(@desviar[:cipher_iv]),
                'hmac'           => @desviar[:hmac]}, $config[:cryptkey])
            @content = obj.for_decrypted_item
          end
          Desviar::Public::log "Fetched #{@desviar.id} #{@desviar.redir_uri} #{@desviar.content.bytesize} #{@desviar.notes[0,50]}"
          erb :content, :layout => false
        end
      else
        error 404
      end
    end

    # handle reCAPTCHA
    post '/:temp_uri' do
      if recaptcha_valid?
        @desviar = Desviar::Model::Main.first(:temp_uri => params[:temp_uri],
                                       :fields => [ :id, :temp_uri, :captcha_validated ])
        @desviar.update(:captcha_validated => true)
      end
      redirect "/desviar/#{params[:temp_uri]}"
    end

    def self.log(message, priority = Syslog::LOG_INFO)
      if $config[:log_facility]    
        Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS | $config[:log_facility]) { |obj| obj.info message }
      end
      puts "#{Time.now} #{message}" if $config[:debug]
    end
  end

=begin
  # TODO - switch to MiniTest, move to test subdir
  class Test <Test::Unit::TestCase
    include Rack::Test::Methods

    def app
      Desviar
    end
 
    def test_list
      get '/list'
      assert last_response.ok?
    end
  end
=end
end

