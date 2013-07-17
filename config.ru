require 'rack/recaptcha'
# Keys for reCAPTCHA - see http://www.google.com/recaptcha/whyrecaptcha
CAPTCHAPUB  = ENV['CAPCHAPUB']
CAPTCHAPRIV = ENV['CAPCHAPRIV']

use Rack::Recaptcha, :public_key => CAPTCHAPUB, :private_key => CAPTCHAPRIV
#helpers Rack::Recaptcha::Helpers

require File.expand_path '../desviar.rb', __FILE__
run Desviar

# TODO: get this to bypass auth for /desviar content
#run Rack::URLMap.new({
#  "/" => Desviar,
#  "/link" => Desviar,
#  "/desviar" => Public,
#  "/create" => Desviar
#})
