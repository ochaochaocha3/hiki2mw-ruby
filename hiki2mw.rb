require "nkf"
require_relative "hiki2mw/common"

source = NKF.nkf("-w", ARGF.read)

puts Hiki2MW.convert(source)
