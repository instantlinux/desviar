module Desviar
  VERSION = "0.0.12"
  RELEASE = "2013-07-29"
  TIMESTAMP = "2013-07-29 11:56:12 -07:00"

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
