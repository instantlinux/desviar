# Desviar - URL redirection for security applications
#
# Created 14 Jul 2013 by rich braun

require 'sinatra'
require 'securerandom'
require 'dm-core'
require 'dm-migrations'
require 'dm-validations'
require 'dm-timestamps'
require 'syntaxi'
require 'net/http'

$title = 'Desviar'
DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite::memory:")
URIPREFIX = ENV['URIPREFIX'] || 'temp2013'

class Desviar
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

  # validates_present :notes
  # validates_length :notes, :minimum => 1

  Syntaxi.line_number_method = 'floating'
  Syntaxi.wrap_at_column = 80
  #Syntaxi.wrap_enabled = false

  def formatted_notes
    replacer = Time.now.strftime('[code-%d]')
    html = Syntaxi.new("[code lang='ruby']#{self.notes.gsub('[/code]',
    replacer)}[/code]").process
    "<div class=\"syntax syntax_ruby\">#{html.gsub(replacer, 
    '[/code]')}</div>"
  end

  def formatted_content
    replacer = Time.now.strftime('[code-%d]')
    html = Syntaxi.new("[code lang='ruby']#{self.content.gsub('[/code]',
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
  @desviar = Desviar.new(:redir_uri => params[:desviar_redir_uri],
                         :notes  => params[:desviar_notes],
                         :expiration => params[:desviar_expiration])
  @desviar[:temp_uri] = "#{URIPREFIX}#{SecureRandom.urlsafe_base64(32)}"
  @desviar[:expires_at] = Time.now + params[:desviar_expiration].to_i

  object = URI.parse(@desviar[:redir_uri])
  http = Net::HTTP.new(object.host, object.port)
  http.use_ssl = @desviar[:redir_uri].index('https') == 0
  response = http.request(Net::HTTP::Get.new(object.request_uri))
  @desviar[:content] = response.body

  if @desviar.save
    redirect "/link/#{@desviar.id}"
  else
    redirect '/create'
  end
end

# display content
get '/desviar/:temp_uri' do
  @desviar = Desviar.get(params[:temp_uri])
  if @desviar && DateTime.now < @desviar[:expires_at]
    erb :content
  else
    error 404
  end
end

# show link ID
get '/link/:id' do
  @desviar = Desviar.get(params[:id])
  if @desviar && DateTime.now < @desviar[:expires_at]
    erb :show
  else
    error 404
  end
end
