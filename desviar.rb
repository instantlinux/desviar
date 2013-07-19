# Desviar - URL redirection for security applications
#
# Created 14 Jul 2013
#
# Copyright 2013 Richard Braun
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

class Desviar < Sinatra::Base
  $title = 'Desviar'
  $debug = false

  # Parameters - passed by environment variables

  # Prefix is an arbitrary string placed at beginning of URI
  URIPREFIX  = ENV['URIPREFIX']  || 'temp2013'
  # Suffix is a hidden string that must be appended to fetch URI
  URISUFFIX  = ENV['URISUFFIX']  || ''
  # AuthSecret is used to randomize password hash
  AUTHSECRET = ENV['AUTHSECRET'] || 'notvery'
  # Admin PW secures the UI
  ADMINPW    = ENV['ADMINPW']    || 'password'
  # DB method - replace with sqlite:///path/file.db to store on disk
# DBMETHOD   = ENV['DBMETHOD']   || 'sqlite::memory:'
    ### TODO: figure out how to maintain a persistent thread for memory DB
  DBMETHOD   = ENV['DBMETHOD']   || 'sqlite:///dev/shm/desviar'

  class Desviar::Data
    include DataMapper::Resource
  
    property :id,         Serial # primary serial key
    property :redir_uri,  String, :required => true, :length => 255
    property :temp_uri,   String, :length => 64
    property :expiration, Integer, :required => true
    property :captcha,    Boolean
    property :captcha_prompt,    Text
    property :captcha_button,    String, :length => 20
    property :captcha_validated, Boolean
    property :content,    Text
    property :notes,      Text
    property :created_at, DateTime
    property :updated_at, DateTime
    property :expires_at, DateTime
  
    Syntaxi.line_number_method = 'floating'
    Syntaxi.wrap_at_column = 80
  
    def formatted_notes
      replacer = Time.now.strftime('[code-%d]')
      html = Syntaxi.new("[code lang='ruby']#{self.notes.gsub('[/code]',
                         replacer)}[/code]").process
      "<div class=\"syntax syntax_ruby\">#{html.gsub(replacer, '[/code]')}</div>"
    end
  end
  
  configure do
    DataMapper::Logger.new($stdout, :debug) if $debug
    DataMapper.setup(:default, DBMETHOD)
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
       :temp_uri       => "#{URIPREFIX}#{SecureRandom.urlsafe_base64(32)}#{URISUFFIX}",
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
    @desviar[:content] = response.body
  
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
    @desviar = Desviar::Data.all(:limit => 150, :order => [ :created_at.desc ])
    @total = @desviar.length
    @count = [ @total, 150 ].min
    erb :list
  end

  def self.new(*)
    app = Rack::Auth::Digest::MD5.new(super) do |username|
      {'desviar' => ADMINPW}[username]
    end
    app.realm = 'Restricted Area'
    app.opaque = AUTHSECRET
    app
  end
end

#############################################
# Class Desviar::Public - routes without auth

class Desviar::Public < Sinatra::Base
  # Keys for reCAPTCHA - see http://www.google.com/recaptcha/whyrecaptcha
  CAPTCHAPUB  = ENV['CAPTCHAPUB']
  CAPTCHAPRIV = ENV['CAPTCHAPRIV']

  configure do
    use Rack::Recaptcha, :public_key => CAPTCHAPUB, :private_key => CAPTCHAPRIV
    helpers Rack::Recaptcha::Helpers
  end

  # display content
  get '/:temp_uri' do
    @desviar = Desviar::Data.first(:temp_uri => params[:temp_uri])
    cache_control :public, :max_age => 30
    if @desviar && DateTime.now < @desviar[:expires_at]
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
