#!/usr/bin/env ruby
# API examples - Desviar::Client
#
# Created 1 Aug 2013
#
#   Copyright 2013 Richard Braun
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0

# Usage:
#  Start the server first (rackup -p 4567)
#  Adjust credentials below if you've modified the server
#  Invoke this program ./ruby-client.rb

#require 'desviar/client'
require 'client'
require 'pp'

obj = Desviar::Client.new 'desviar', 'password'
puts "Starting Desviar::Client for server #{obj.server_uri} as user #{obj.user_name}"

puts "========= Desviar::Client config =========="
puts "dbencrypt is #{obj.config_item 'dbencrypt'}"
puts "debug is #{obj.config_item :debug}"
puts "Full config hash is:"
pp obj.config

puts "========= Desviar::Client list ============"
pp obj.list
begin
  pp obj.list_item 999
rescue ArgumentError
  puts "Handling expected error for item 999"
end
