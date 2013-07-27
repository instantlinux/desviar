# Data model for Desviar main object
#
#   Copyright 2013 Richard Braun
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0

class Desviar::Data
  include DataMapper::Resource
  
  property :id,         Serial # primary serial key
  property :redir_uri,  String, :required => true, :length => 255
  property :temp_uri,   String, :length => 64
  property :expiration, Integer, :required => true
  property :captcha,    Boolean
  property :captcha_prompt,    Text
  property :captcha_button,    String, :length => 20
  property :captcha_validated, Boolean
  property :content,    Text,  :length => $config[:contentmax]
  property :notes,      Text
  property :cipher_iv,  Binary, :length => 16
  property :hmac,       String, :length => 46
  property :owner,      String, :length => 16
  property :created_at, DateTime
  property :updated_at, DateTime
  property :expires_at, DateTime
  
  Syntaxi.line_number_method = 'floating'
  Syntaxi.wrap_at_column = 80

  def formatted_notes
    sub = Time.now.strftime('[code-%d]')
    html = Syntaxi.new("[code lang='ruby']#{self.notes.gsub('[/code]',sub)}
                        [/code]").process
    "<div class=\"syntax syntax_ruby\">#{html.gsub(sub, '[/code]')}</div>"
  end
end
