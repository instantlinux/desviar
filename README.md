### Desviar - High-security redirection ###

This is a Ruby-based app server built on Sinatra to create
preauthorized time-limited, random URIs used in devops deployment
scripts or in web applications such as confirmation emails.  Your
scenario is that you have a database, repository or webserver
(possibly behind a firewall) that needs to stay both hidden and
secure, but you need to provide a means for a script to invoke an API
call or for a remote user to click a direct link to fetch a specific
item from its hidden source without presenting credentials.

It operates similarly to TinyURL or the Amazon S3 temporary-URI
feature: provide the tool with the URI and credentials to an existing
secure resource, specify a number of seconds you want to authorize
references to it, and you'll get back a temporary URI good for that
amount of time.  An analogy is the inexpensive key-card issued by a
hotel's desk clerk: to access secure content in the room, you first
need to present your credit-card credentials; your room key is all you
need thereafter, at least until the key expires.  The hotel remains
secure even if you keep the key after checkout.

You can set up desviar on a DMZ network or in the cloud behind an
iptables/nginx configuration to provide whatever ACL restrictions you
want, and you can reference any source URI (not just those stored on
S3 or an equivalent service).

Secure content is encrypted and cached in memory (sqlite3) by default;
for troubleshooting, you can store content in a file and/or turn off
encryption.

#### Installation ####

These directions have been tested on Ubuntu 12.10 and OpenSUSE 12.3.

##### From github #####
Clone this repo and perform the following:

    git clone https://github.com/instantlinux/desviar.git
    cd desviar
    cp config/config.rb.example config/config.rb
    sudo apt-get install -y make g++ libsqlite3-dev ruby-dev
    #  package names above may differ if not using Ubuntu
    sudo gem install bundler
    sudo bundle install
    export RUBYLIB=`pwd`/lib
    rackup -p 4567

##### From rubygems.org #####
[![Gem Version](https://badge.fury.io/rb/desviar.png)](http://badge.fury.io/rb/desviar) Invoke the following:

    sudo apt-get install -y make g++ libsqlite3-dev ruby-dev
    sudo gem install desviar
    wget https://raw.github.com/instantlinux/desviar/master/config.ru
    wget https://raw.github.com/instantlinux/desviar/master/config/config.rb.example
    cp config.rb.example config.rb
    export DESVIAR_CONFIG=`pwd`/config.rb
    rackup -p 4567

#### Usage ####

In your browser, the [app](http://localhost:4567)'s default credential upon installation is user _desviar_, pw _password_.

Commands:
* /create - generate a new pre-authenticated URI
* /desviar/xxx - retrieve pre-authenticated content (if a URISUFFIX was specified, it must be appended to xxx)
* /list   - display a table of most-recently uploaded URIs
* /link/nnn - retrieve details
* /config - set runtime configuration

For scripting, the list, link and config commands can be modified with a _/json_ suffix (e.g. _/config/json_) to generate json instead of html output.  Script examples for Ruby and bash are provided in the [examples directory](https://github.com/instantlinux/desviar/tree/master/examples).

Security notes:
Consider moving the default database location from /dev/shm/desviar, and set its permissions to 0600. You can modify config.ru to direct log output to a different file.

User credentials:
A file called .htdigest is part of this package (see https://raw.github.com/instantlinux/desviar/master/config/.htdigest); you can customize the list using the _htdigest_ utility (get it from [htdigest-ruby](https://rubygems.org/gems/htdigest-ruby) and define environment variable DESVIAR_HTDIGEST with the pathname of your customized file.  The configuration parameter _adminuser_ defines a "super-user" which can view/set configuration at run-time, and can access records other than its own via the list and link commands.

#### Features implemented ####

- [x] HTTP digest authentication for client API and user interface
- [x] Multiple credentials, with designated _adminuser_
- [x] Parse htdigest (password) file
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
