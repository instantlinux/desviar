require 'desviar'

log = File.new("/tmp/desviar.log", "a+", 0600)
  $stdout.reopen(log)
  $stderr.reopen(log)

run Rack::URLMap.new({
  "/" => Desviar::Authorized,
  "/desviar"  => Desviar::Public
})
