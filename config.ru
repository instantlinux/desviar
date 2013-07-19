require File.expand_path '../desviar.rb', __FILE__

run Rack::URLMap.new({
  "/" => Desviar,
  "/0/link"   => Desviar,
  "/0/create" => Desviar,
  "/0/list"   => Desviar,
  "/desviar"  => Desviar::Public
})
