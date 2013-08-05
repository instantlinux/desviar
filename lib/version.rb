module Desviar
  VERSION = "0.0.18"
  RELEASE = "2013-08-04"
  TIMESTAMP = "2013-08-04 22:38:12 -07:00"

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
