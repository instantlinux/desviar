require File.expand_path '../desviar.rb', __FILE__
run Desviar

# TODO: get this to bypass auth for /desviar content
#run Rack::URLMap.new({
#  "/" => Desviar,
#  "/link" => Desviar,
#  "/desviar" => Public,
#  "/create" => Desviar
#})
