# Authorization module for Desviar - RFC 2317 htdigest support
#
#   Copyright 2013 Richard Braun
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0

module Desviar
  class Auth
    def initialize(htdigest_file, adminuser, realm, authsalt)
      @users = Hash.new
      File.open(htdigest_file) do |f|
        f.each_line do |line|
          if line.split(':')[1] == realm
            @users[line.split(':')[0]] = line.split(':')[2].strip
          end
        end
      end
      @realm     = realm
      @adminuser = adminuser
      @authsalt  = authsalt
    end

    def authenticate!(app)
      auth = Rack::Auth::Digest::MD5.new(app) do |username|
        @users[username]
      end
      auth.realm  = @realm
      auth.opaque = @authsalt
      auth.passwords_hashed = true
      auth
    end

=begin
    # TODO: figure out how to access Rack::Request environment
    def authorized?(owner)
      request.env['REMOTE_USER'] == @adminuser ||
            request.env['REMOTE_USER'] == owner
    end

    def authsuper?
      request.env['REMOTE_USER'] == @adminuser
    end

    def user_name
      request.env['REMOTE_USER']
    end
=end
  end
end
