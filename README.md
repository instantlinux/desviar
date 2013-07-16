### Desviar - High-security redirection ###

This is a Ruby tool built on Sinatra to create time-limited, random URIs
used in deployment scripts.

It operates similarly to the Amazon S3 temporary-URI feature:  provide
the tool with the URI to an existing resource, specify a number of seconds
you want to reference it, and you'll get back a temporary URI good for
that amount of time.

Unlike S3, with this tool you can put it behind an iptables/nginx
configuration to provide whatever ACL restrictions you want, and you
can reference any source URI (not just those stored on S3).

#### Usage ####

Clone this repo and perform the following:

    sudo apt-get install rack
    sudo gem install sinatra dm-core dm-migrations dm-validations dm-timestamps syntaxi
    rackup -p 4567

Default credential is user _desviar_, pw _password_.

#### License ####

Created under Apache license by rich braun, July 2013.
