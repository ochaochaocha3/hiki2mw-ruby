require "nkf"
require_relative "hiki2mw/common"

source = ""
while line = gets
  source << line
end
source = NKF.nkf("-w", source)

puts Hiki2MW.convert(source)
