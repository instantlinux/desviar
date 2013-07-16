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

class Desviar < Sinatra::Base
  $title = 'Desviar'

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
  DBMETHOD   = ENV['DBMETHOD']   || 'sqlite::memory:'

  DataMapper.setup(:default, DBMETHOD)

  class Desviar::Data
    include DataMapper::Resource
  
    property :id,         Serial # primary serial key
    property :redir_uri,  String, :required => true, :length => 255
    property :notes,      Text
    property :temp_uri,   String, :length => 64
    property :expiration, Integer, :required => true
    property :content,    Text
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
  
  DataMapper.auto_upgrade!
  
  get '/' do
    redirect '/create'
  end
  
  # create
  get '/create' do
    erb :create
  end
  
  # submit
  post '/create' do
    @desviar = Desviar::Data.new(:redir_uri => params[:desviar_redir_uri],
                           :notes  => params[:desviar_notes],
                           :expiration => params[:desviar_expiration])
    @desviar[:temp_uri] = "#{URIPREFIX}#{SecureRandom.urlsafe_base64(32)}#{URISUFFIX}"
    @desviar[:expires_at] = Time.now + params[:desviar_expiration].to_i
  
    object = URI.parse(@desviar[:redir_uri])
    http = Net::HTTP.new(object.host, object.port)
    http.use_ssl = @desviar[:redir_uri].index('https') == 0
    response = http.request(Net::HTTP::Get.new(object.request_uri))
    @desviar[:content] = response.body
  
    if @desviar.save
      redirect "/link/#{@desviar.id}"
    else
      error 400
    end
  end
  
  # display content
  get '/desviar/:temp_uri' do
    @desviar = Desviar::Data.first(:temp_uri => params[:temp_uri])
    if @desviar && DateTime.now < @desviar[:expires_at]
      erb :content
    else
      error 404
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

  def self.new(*)
    app = Rack::Auth::Digest::MD5.new(super) do |username|
      {'desviar' => ADMINPW}[username]
    end
    app.realm = 'Restricted Area'
    app.opaque = AUTHSECRET
    app
  end
end

class Public < Desviar
end
