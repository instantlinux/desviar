require 'htauth'

module Sinatra
 module Authorization
  module HelperMethods

  def passwd_file
    File.expand_path '../config/.htpasswd', __FILE__
  end

  def auth
    @auth ||= Rack::Auth::Basic::Request.new(request.env)
#    @auth ||= Rack::Auth::Digest::MD5.new(request.env)
  end

  def unauthorized!(realm = "Please Authenticate")
    header 'WWW-Authenticate' => %(Basic realm="#{realm}")
    throw :halt, [ 401, 'Authorization Required' ]
  end

  def bad_request!
    throw :halt, [ 400, 'Bad Request' ]
  end

  def authorized?
    request.env['REMOTE_USER']
  end

  def authorize(username, password)
    return false if !File.exists?(passwd_file)
    pf = HTAuth::PasswdFile.new(passwd_file)
    user = pf.fetch(username)
    !user.nil? && user.authenticated?(password)
  end

  def require_administrative_privileges
    return if authorized?
    unauthorized! unless auth.provided?
    bad_request! unless auth.basic?
    unauthorized! unless authorize(*auth.credentials)
    request.env['REMOTE_USER'] = auth.username
  end

  def admin?
    authorized?
  end

  
  end
  def self.registered(app)
    app.helpers HelperMethods
  end
 end
 register Authorization
end
