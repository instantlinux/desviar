### Desviar - High-security redirection ###

This is a Ruby-based app server built on Sinatra to create
preauthorized time-limited, random URIs used in devops deployment
scripts or in web applications such as confirmation emails.

It operates similarly to the Amazon S3 temporary-URI feature:  provide
the tool with the URI to an existing secure resource, specify a number
of seconds you want to authorize references to it, and you'll get back
a temporary URI good for that amount of time.

You can set it up on a DMZ network or in the cloud behind an
iptables/nginx configuration to provide whatever ACL restrictions you
want, and you can reference any source URI (not just those stored on
S3).

Secure content is cached in memory (sqlite3) by default; for
troubleshooting, you can store content in a file.

#### Installation ####

Clone this repo and perform the following:

    sudo apt-get install rack libsqlite3-dev
    #  package names above may differ if not using Ubuntu
    sudo gem install bundler
    bundle install
    export URIPREFIX=something
    export AUTHSECRET=auniquevalue
    export ADMINPW=mypassword
    export CAPTCHAPUB=key
    export CAPTCHAPRIV=key
    rackup -p 4567

Default credential is user _desviar_, pw _password_.

#### Usage ####

Commands:
* /create - generate a new pre-authenticated URI
* /desviar/xxx - retrieve pre-authenticated content (if a URISUFFIX was specified, it must be appended to xxx)
* /list   - display a table of most-recently uploaded URIs
* /link/nnn - retrieve details

Here's an example of creating a new link via _curl_:

    curl --digest --user desviar:password http://localhost:4567/create \
     --data "desviar_redir_uri=http://localhost/test&desviar_expiration=1800&desviar_captcha=1&desviar_notes=testing"

#### Features implemented ####

- [x] HTTP digest authentication for user interface
- [ ] Parse htpasswd files to support multiple credentials
- [x] Bypass authentication for generated URIs
- [x] Basic HTTP authentication for remote URIs
- [ ] HTTP digest authentication for remote URIs
- [x] reCAPTCHA challenge for generated URIs
- [x] Listing of database contents
- [ ] Encrypt database
- [ ] Memcached storage (for performance at scale)
- [x] Pre-shared/concealed URI suffix
- [ ] Activity log output (syslog)
- [x] Database cleanup tool

#### License ####

Created under Apache license by rich braun, July 2013.

 Copyright 2013 Richard Braun

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at 
       [Apache.org](http://www.apache.org/licenses/LICENSE-2.0)
