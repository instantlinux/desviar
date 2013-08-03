module Desviar
  VERSION = "0.0.16"
  RELEASE = "2013-08-03"
  TIMESTAMP = "2013-08-03 09:12:27 -07:00"

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
