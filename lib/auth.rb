require 'webrick/httpauth/htpasswd'

module Desviar::Auth

    def self.htpasswd
#      @htpasswd ||= Htpasswd.new(git.path_to("htpasswd"))
      @htpasswd ||= Htpasswd.new('.htpasswd')
    end

    def self.authentication
      @authentication ||= Rack::Auth::Basic::Request.new request.env
    end

    def self.authenticated?
      request.env["REMOTE_USER"] && request.env["desviar.authenticated"]
    end

    def self.authenticate(username, password)
      checked   = [ username, password ] == authentication.credentials
      validated = authentication.provided? && authentication.basic?
      granted   = htpasswd.authenticated? username, password
      if checked and validated and granted
        request.env["desviar.authenticated"] = true
        request.env["REMOTE_USER"] = authentication.username
      else
        nil
      end
    end

#    def self.unauthorized!(realm = Desviar::info)
    def self.unauthorized!(realm = 'desviar-realm')
      headers "WWW-Authenticate" => %(Basic realm="#{realm}")
      throw :halt, [ 401, "Authorization Required" ]
    end

    def self.bad_request!
      throw :halt, [ 400, "Bad Request" ]
    end

    def self.authenticate!
      return if authenticated?
      unauthorized! unless authentication.provided?
      bad_request!  unless authentication.basic?
      unauthorized! unless authenticate(*authentication.credentials)
      request.env["REMOTE_USER"] = authentication.username
    end

    def self.access_granted?(username, password)
      authenticated? || authenticate(username, password)
    end

end

class Desviar::Auth2

      def initialize(file)
        @handler = WEBrick::HTTPAuth::Htpasswd.new(file)
        yield self if block_given?
      end

      def find(username)
        password = @handler.get_passwd(nil, username, false)
        if block_given?
          yield password ? [password, password[0,2]] : [nil, nil]
        else
          password
        end
      end

      def authenticated?(username, password)
        self.find username do |crypted, salt|
          crypted && salt && crypted == password.crypt(salt)
        end
      end

      def create(username, password)
        @handler.set_passwd(nil, username, password)
      end
      alias update create

      def destroy(username)
        @handler.delete_passwd(nil, username)
      end

      def include?(username)
        users.include? username
      end

      def size
        users.size
      end

      def write!
        @handler.flush
      end

      private

      def users
        @handler.each{|username, password| username }
      end
    end
