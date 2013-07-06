require "nkf"
require_relative "hiki2mw/common"

source = ""
while line = gets
  source << NKF.nkf("-w", line)
end

puts Hiki2MW.convert(source)
