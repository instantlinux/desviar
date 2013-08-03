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

require 'desviar/client'
require 'pp'

obj = Desviar::Client.new 'desviar', 'password'
puts "Starting Desviar::Client for server #{obj.server_uri} as user #{obj.user_name}"

puts "========= Desviar::Client config =========="
puts "dbencrypt is #{obj.config_item 'dbencrypt'}"
puts "debug is #{obj.config_item :debug}"
puts "Full config hash is:"
pp obj.config

puts "========= Desviar::Client create =========="
# Can specify option names using symbols/strings; values must be strings

#  The notes field is an arbitrary payload which can be used for
#  whatever tracking purposes your application requires.

#  Example 1: create an item valid for 5 seconds to demonstrate
#  cleanup after 6 seconds.  Fetch will invoke captcha (get credentials
#  from Google for a "real" test)
link = obj.create "https://rubygems.org/gems/desviar", 5, {
   :captcha => 1.to_s,
   "notes"  => "tracking-item" }
puts link['temp_uri'].inspect
puts obj.fetch link['temp_uri']

# Example 2: same as #1 except without captcha
link = obj.create "https://rubygems.org/gems/desviar", 5, {
   "notes"  => "tracking example 2" }
puts link['temp_uri'].inspect
puts obj.fetch link['temp_uri']

# Example 3: valid for 10 minutes 
pp obj.create "https://rubygems.org/gems/desviar", 600, {
   "notes"  => "example 3" }

puts "========= Desviar::Client list ============"
pp obj.list
begin
  pp obj.list_item 999
rescue ArgumentError
  puts "Handling expected error for item 999"
end

puts "========= Desviar::Client clean ============"
sleep 6
obj.clean
pp obj.list
