require "kconv"
require_relative "hiki2mw/converter"

source = ARGF.read.toutf8

puts Hiki2MW.convert(source)
