require './desviar'

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
  spec.require_paths     = ["config", "lib", "public", "views"]
  spec.files             = %x[git ls-files].split.reject do |out|
    out =~ %r{^\.} || out =~ %r{/^doc/api/}
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

    Thanks for using Desviar.
    #{'-'*78}
  end
  spec.add_dependency "sinatra", ">= 1.4"
end
