require File.expand_path '../desviar.rb', __FILE__
log = File.new("desviar.log", "a+")
  $stdout.reopen(log)
  $stderr.reopen(log)

run Rack::URLMap.new({
  "/" => Desviar,
  "/0/config" => Desviar,
  "/0/create" => Desviar,
  "/0/link"   => Desviar,
  "/0/list"   => Desviar,
  "/desviar"  => Desviar::Public
})
