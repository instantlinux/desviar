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
require File.expand_path '../auth', __FILE__
$digest_file = ENV['DESVIAR_HTDIGEST'] || (File.expand_path '../../config/.htdigest', __FILE__)

module Desviar

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
      if @desviar && DateTime.now < @desviar[:expires_at] && @desviar[:num_uses] !=0
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
          if @desviar[:num_uses] > 0
            @desviar.update(:num_uses => @desviar[:num_uses] - 1)
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
        @desviar = Desviar::Model::Main.first(
                       :temp_uri => params[:temp_uri],
                       :fields => [ :id, :temp_uri, :captcha_validated ])
        @desviar.update(:captcha_validated => true)
      end
      redirect "/desviar/#{params[:temp_uri]}"
    end

    # Syslog utility
    def self.log(message, priority = Syslog::LOG_INFO)
      if $config[:log_facility]    
        Syslog.open($0, Syslog::LOG_PID | Syslog::LOG_CONS | $config[:log_facility]) { |obj| obj.info message }
      end
      puts "#{Time.now} #{message}" if $config[:debug]
    end
  end

  #############################################
  # Class Desviar::Authorized - routes (commands) which require authorization

  class Authorized < Sinatra::Base

    configure do
      DataMapper::Logger.new($stdout, :debug) if $config[:debug]
      DataMapper.setup(:default, $config[:dbmethod])
      DataMapper.auto_upgrade! if DataMapper.respond_to?(:auto_upgrade!)
      $config[:cryptkey] = SecureRandom.base64(32) if $config[:cryptkey].nil?
      helpers Sinatra::JSON
      @auth = Desviar::Auth.new($digest_file, $config[:adminuser], $config[:authprompt], $config[:authsalt])
      Desviar::Public::log "Starting #{Desviar.info}"
    end

    get '/' do
      redirect '/create'
    end
  
    # form: new temporary URI
    get '/create' do
      puts request.env.inspect if $config[:debug]
      erb :create
    end
  
    # create new temporary URI
    post '/create' do
      error 400 if params[:redir_uri].strip == ""

      # Create a new data record, generating the random URI and omitting
      #   remote-access credentials if specified.
      @desviar = Desviar::Model::Main.new(params.merge({
        :temp_uri => "#{$config[:uriprefix]}#{SecureRandom.urlsafe_base64($config[:hashlength])[0,$config[:hashlength]]}#{$config[:urisuffix]}",
        :expires_at     => Time.now + params[:expiration].to_i,
        :captcha_validated => false,
        :owner => request.env['REMOTE_USER']
      }).delete_if {|key, val| key == "redir_uri" || key == "remoteuser" || key == "remotepw"})

      # Cache the remote URI
      object = URI.parse(params[:redir_uri])
      http = Net::HTTP.new(object.host, object.port)
      http.use_ssl = params[:redir_uri].index('https') == 0
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      req = Net::HTTP::Get.new(object.request_uri)
      if params[:remoteuser] != ''
        req.basic_auth params[:remoteuser], params[:remotepw]
      end
      begin
        response = http.request(req)
      rescue Errno::ECONNREFUSED
        error 401
      end
      if response.code.to_i != 200
        error response.code.to_i 
      end
      if !$config[:dbencrypt]
        @desviar[:content] = response.body[0, $config[:contentmax]]
      else
        obj = Desviar::EncryptedItem::Encryptor.new(
                  response.body[0, $config[:contentmax]], $config[:cryptkey])
        @desviar[:content]   = obj.encrypted_data
        @desviar[:hmac]      = obj.hmac
        @desviar[:cipher_iv] = obj.iv
      end

      # Apply field rules:
      #  - Discard redir_uri from data record if redir_retain != 'keep'
      #  - Set num_uses to -1 (unlimited) if not set
      @desviar[:redir_uri] = $config[:redir_retain] == "keep" ? params[:redir_uri] : ""
      if @params[:num_uses].to_i <= 0 || @params[:num_uses].empty?
        @desviar[:num_uses] = -1
      end

      # Insert the new record and display the new link
      if @desviar.save
        Desviar::Public::log "Created #{@desviar.id} #{@desviar.redir_uri} #{@desviar.expires_at} #{@desviar.num_uses} #{request.ip} #{request.env['REMOTE_USER']}"
        redirect "/link/#{@desviar.id}"
      else
        error 400
      end
    end
  
    # show link metadata info
    get '/link/:id' do
      @desviar = Desviar::Model::Main.get(params[:id])
      if @desviar && DateTime.now < @desviar[:expires_at] &&
        (request.env['REMOTE_USER'] == $config[:adminuser] ||
         request.env['REMOTE_USER'] == @desviar['owner'])
        erb :show
      else
        error 404
      end
    end

    # show link info - json format
    get '/link/json/:id' do
      @desviar = Desviar::Model::Main.get(params[:id])
      if @desviar && DateTime.now < @desviar[:expires_at] &&
        (request.env['REMOTE_USER'] == $config[:adminuser] ||
         request.env['REMOTE_USER'] == @desviar['owner'])
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
      query = {
         :expires_at.lt => DateTime.now,
         :fields => [ :id ]
      }
      if request.env['REMOTE_USER'] != $config[:adminuser]
        query[:owner] = request.env['REMOTE_USER']
      end
      @records = Desviar::Model::Main.all(query)
      count = @records.length
      @records.each do |item|
        @desviar.execute("DELETE FROM desviar_model_mains WHERE id=#{item.id};")
      end
      Desviar::Public::log "Cleaned #{count} records by #{request.env['REMOTE_USER']}" if count != 0
      redirect "/list"
    end

    # list most recent records
    get '/list' do
      query = {
         :limit => $config[:recordsmax],
         :order => [ :created_at.desc ],
         :fields => [ :id, :created_at, :expires_at, :redir_uri, :captcha, :notes ]
      }
      if request.env['REMOTE_USER'] != $config[:adminuser]
        query[:owner] = request.env['REMOTE_USER']
      end
      @desviar = Desviar::Model::Main.all(query)
      @total = @desviar.length
      @count = [ @total, $config[:recordsmax] ].min
      erb :list
    end

    # list - json
    get '/list/json' do
      query = {
         :limit => $config[:recordsmax],
         :order => [ :created_at.desc ],
         :fields => [ :id, :created_at, :expires_at, :redir_uri, :captcha, :notes ]
      }
      if request.env['REMOTE_USER'] != $config[:adminuser]
        query[:owner] = request.env['REMOTE_USER']
      end
      @desviar = Desviar::Model::Main.all(query)
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

    # form - configuration
    get '/config' do
      @ver = Desviar.info
      if request.env['REMOTE_USER'] == $config[:adminuser]
        erb :config
      else
        error 404
      end
    end

    # query configuration - json
    get '/config/json' do
      if request.env['REMOTE_USER'] == $config[:adminuser]
        json $config.reject { |opt, val| 
          opt.to_s.index('msg_') == 0 ||
          $config[:hidden].include?(opt.to_s) ||
          $config[:hashed].include?(opt.to_s)
        }
      else
        error 404
      end
    end

    # config update
    post '/config' do
      if request.env['REMOTE_USER'] == $config[:adminuser]
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
        Desviar::Public::log "Configuration updated by #{request.env['REMOTE_USER']}"
        redirect "/list"
      else
        error 404
      end
    end

    def self.new(*)
      app = @auth.authenticate!(super)
#     TODO - scope of request.env is needed
#     user = request.env['REMOTE_USER']
      Desviar::Public::log "Authenticated new user session"
      app
    end
  end
end

