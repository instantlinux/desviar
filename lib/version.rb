module Desviar
  VERSION = "0.0.11"
  RELEASE = "2013-07-29"
  TIMESTAMP = "2013-07-29 10:48:22 -07:00"

  def self.info
      "#{name} v#{VERSION} (#{RELEASE})"
    end

  def self.to_h
    { :name      => name,
      :version   => VERSION,
      :release   => RELEASE,
      :timestamp => TIMESTAMP,
      :info      => info }
  end
end
