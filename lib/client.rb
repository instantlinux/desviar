# Client functions for Desviar main object
#
#   Copyright 2013 Richard Braun
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0

require 'json'
require 'uri'
require 'net/http'
require 'net/http/digest_auth'

module Desviar
  class Client
    ##
    # Client functions for Desviar main object

    # Create new client
    def initialize(user_name, private_key, server_uri = 'http://localhost:4567')
      @server_uri = server_uri
      @user_name = user_name
      @private_key = private_key
    end

    # Return server's URI
    def server_uri()
      @server_uri
    end

    # Return username
    def user_name()
      @user_name
    end

    # Fetch configuration (as a hash)
    def config
      JSON.parse get("config/json")
    end

    # Fetch a single configuration item
    def config_item(item)
      cfg = JSON.parse get("config/json")
      raise ArgumentError, "Invalid item #{item}" if !cfg.has_key?(item.to_s)
      cfg[item.to_s]
    end

    # Fetch list of stored redirects
    def list
      JSON.parse get("list/json")
    end

    # Fetch meta information about a particular redirect
    def list_item(id)
      JSON.parse get("link/json/#{id}")
    end

    # Clean out expired entries
    def clean
      get("clean")
    end

    # Create a new redirect
    def create(uri, expiration = 900, opts = {})
      raise "not yet implemented"
    end

    private

    # Internal function:  raw, digest-authenticated HTTP get from server
    def get(path)
      uri              = URI.parse "#{@server_uri}/#{path}"
      uri.user         = @user_name
      uri.password     = @private_key

      http             = Net::HTTP.new uri.host, uri.port
      http.use_ssl     = @server_uri.index('https') == 0
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      req              = Net::HTTP::Get.new(uri.request_uri)
      response         = http.request req
      auth             = Net::HTTP::DigestAuth.new.auth_header(
                            uri, response['www-authenticate'], 'GET')
      req              = Net::HTTP::Get.new uri.request_uri
      req.add_field 'Authorization', auth
      response         = http.request req
      raise ArgumentError, "#{path} return status #{response.code}" if response.code.to_i != 200
      response.body
    end
  end
end
