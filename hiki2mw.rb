require "nkf"
require_relative "hiki2mw/common"

source = ""
while line = ARGV.shift
  source << line
end
source = NKF.nkf("-w", open(source).read)

puts Hiki2MW.convert(source)
