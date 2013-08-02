#!/bin/bash
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
#  Invoke this program ./bash-client.sh

curl --digest --user desviar:password http://localhost:4567/create \
     --data "redir_uri=http://rubygems.com/gems/desviar&expiration=1800&captcha=1&notes=testing"
echo
echo "========= Desviar::Client config =========="
curl --digest --user desviar:password http://localhost:4567/config/json
echo
echo "========= Desviar::Client list ============"
curl --digest --user desviar:password http://localhost:4567/list/json
