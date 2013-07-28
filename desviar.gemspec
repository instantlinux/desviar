require 'desviar'

Gem::Specification.new do |spec|
  spec.platform          = Gem::Platform::RUBY
  spec.name              = "desviar"
  spec.summary           = "Preauthorized secure/random URI redirection"
  spec.authors           = ["Rich Braun"]
  spec.email             = "richb@instantlinux.net"
  spec.homepage          = "http://github.com/instantlinux/desviar"
  spec.rubyforge_project = spec.name
  spec.version           = Desviar::VERSION
  spec.date              = Desviar::RELEASE
# spec.test_files        = spec.files.select{ |path| path =~ /^test\/.*/ }
  spec.require_paths     = ["config", "lib"]
  spec.files             = %x[git ls-files].split.reject do |out|
    out =~ %r{^\.} || out =~ %r{/^doc/api/} || out =~ %r{^Gemfile}
  end
  spec.description       = <<-end.gsub /^    /,''
    Desviar provides URL redirection; some possible applications include:
    - Web signup process
    - Continuous-deploy servers
    - Online ticket sales
  end
  spec.post_install_message = <<-end.gsub(/^[ ]{4}/,'')
    #{'-'*78}
    Desviar v#{spec.version}

    To configure, download from:
       https://raw.github.com/instantlinux/desviar/master/config/config.rb.example
    into a new file config.rb and export DESVIAR_CONFIG=<path>/config.rb.

    Thanks for using Desviar.
    #{'-'*78}
  end
  spec.add_dependency "dm-core", ">= 1.2"
  spec.add_dependency "dm-migrations", ">= 1.2"
  spec.add_dependency "dm-sqlite-adapter", ">= 1.2"
  spec.add_dependency "dm-timestamps", ">= 1.2"
  spec.add_dependency "dm-validations", ">= 1.2"
  spec.add_dependency "rack-recaptcha", ">= 0.6"
  spec.add_dependency "rack-test", ">= 0.6"
  spec.add_dependency "sinatra", ">= 1.4"
  spec.add_dependency "syntaxi", ">= 0.5"
  spec.add_dependency "yajl-ruby", ">= 1.1"
end
