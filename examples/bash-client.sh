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

echo "========= Desviar::Client config =========="
curl --digest --user desviar:password -q http://localhost:4567/config/json
echo
echo "========= Desviar::Client create =========="
#  In this example, create an item valid for 5 seconds and another valid for
#  10 minutes to demonstrate cleanup after 6 seconds.  The notes field is
#  an arbitrary payload which can be used for whatever tracking purposes
#  your application requires.
id=`curl -q --digest --user desviar:password http://localhost:4567/create \
     --data "redir_uri=https://rubygems.org/gems/desviar&expiration=5&captcha=1&notes=tracking-item" \
   --location |grep ID:|egrep -o [0-9]+`
curl --digest --user desviar:password -q http://localhost:4567/link/json/$id
echo
id=`curl -q --digest --user desviar:password http://localhost:4567/create \
     --data "redir_uri=https://rubygems.org/gems/desviar&expiration=600&notes=item%202" \
   --location |grep ID:|egrep -o [0-9]+`
curl --digest --user desviar:password -q http://localhost:4567/link/json/$id
echo
echo "========= Desviar::Client list ============"
curl --digest --user desviar:password -q http://localhost:4567/list/json
echo
echo "========= Desviar::Client clean ============"
sleep 6
curl --digest --user desviar:password -q http://localhost:4567/clean
curl --digest --user desviar:password -q http://localhost:4567/list/json
echo
