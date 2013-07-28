module Desviar
  VERSION = "0.0.9"
  RELEASE = "2013-07-28"
  TIMESTAMP = "2013-07-28 22:49:26 -07:00"

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
