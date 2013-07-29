### Desviar - High-security redirection ###

This is a Ruby-based app server built on Sinatra to create
preauthorized time-limited, random URIs used in devops deployment
scripts or in web applications such as confirmation emails.

It operates similarly to TinyURL or the Amazon S3 temporary-URI
feature: provide the tool with the URI to an existing secure resource,
specify a number of seconds you want to authorize references to it,
and you'll get back a temporary URI good for that amount of time.

You can set it up on a DMZ network or in the cloud behind an
iptables/nginx configuration to provide whatever ACL restrictions you
want, and you can reference any source URI (not just those stored on
S3).

Secure content is cached in memory (sqlite3) by default; for
troubleshooting, you can store content in a file.

#### Installation ####

These directions have been tested on Ubuntu 12.10 and OpenSUSE 12.3.

##### From github #####
Clone this repo and perform the following:

    git clone https://github.com/instantlinux/desviar.git
    cd desviar
    cp config/config.rb.example config/config.rb
    sudo apt-get install -y make libsqlite3-dev ruby-dev
    #  package names above may differ if not using Ubuntu
    sudo gem install bundler
    sudo bundle install
    export RUBYLIB=`pwd`/lib
    rackup -p 4567

##### From rubygems.org #####
Invoke the following:

    sudo apt-get install -y make libsqlite3-dev ruby-dev
    sudo gem install desviar
    wget https://raw.github.com/instantlinux/desviar/master/config.ru
    wget https://raw.github.com/instantlinux/desviar/master/config/config.rb.example
    cp config.rb.example config.rb
    export DESVIAR_CONFIG=`pwd`/config.rb
    rackup -p 4567

#### Usage ####

Default credential of [app](http://localhost:4567) is user _desviar_, pw _password_.  

Commands:
* /create - generate a new pre-authenticated URI
* /desviar/xxx - retrieve pre-authenticated content (if a URISUFFIX was specified, it must be appended to xxx)
* /list   - display a table of most-recently uploaded URIs
* /link/nnn - retrieve details
* /config - set runtime configuration

For scripting, the list, link and config commands can be modified with a _/json_ suffix (e.g. _/config/json_) to generate json instead of html output.

Here's an example of creating a new link via _curl_:

    curl --digest --user desviar:password http://localhost:4567/create \
     --data "redir_uri=http://localhost/test&expiration=1800&captcha=1&notes=testing"

Security notes:
Consider moving the default database location from /dev/shm/desviar, and set its permissions to 0600. You can modify config.ru to direct log output to a different file.

#### Features implemented ####

- [x] HTTP digest authentication for user interface
- [ ] Parse htpasswd files to support multiple credentials
- [x] Bypass authentication for generated URIs
- [x] Basic HTTP authentication for remote URIs
- [ ] HTTP digest authentication for remote URIs
- [x] reCAPTCHA challenge for generated URIs
- [x] Listing of database contents
- [x] Choice of static or dynamic (REST) configuration
- [x] Encrypted database
- [ ] Memcached storage (for performance at scale)
- [x] Pre-shared/concealed URI suffix
- [x] Activity log output (syslog)
- [x] Database cleanup tool
- [x] Tested under Ruby 1.9.3

#### License ####

Created under Apache license by rich braun, July 2013.

 Copyright 2013 Richard Braun

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at 
       [Apache.org](http://www.apache.org/licenses/LICENSE-2.0)
