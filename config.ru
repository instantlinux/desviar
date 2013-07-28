require File.expand_path '../desviar.rb', __FILE__
log = File.new("desviar.log", "a+")
  $stdout.reopen(log)
  $stderr.reopen(log)

run Rack::URLMap.new({
  "/" => Desviar::Authorized,
  "/0/config" => Desviar::Authorized,
  "/0/create" => Desviar::Authorized,
  "/0/link"   => Desviar::Authorized,
  "/0/list"   => Desviar::Authorized,
  "/desviar"  => Desviar::Public
})
