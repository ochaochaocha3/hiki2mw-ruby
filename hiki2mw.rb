require "kconv"
require_relative "hiki2mw/common"

source = ARGF.read.toutf8

puts Hiki2MW.convert(source)
