require_relative "hiki2mw/common"

source = ""
while line = gets
  source << line
end

puts Hiki2MW.convert(source)
