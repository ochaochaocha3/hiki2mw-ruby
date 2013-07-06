require_relative "converter"

module Hiki2MW
  module_function
  def convert(source)
    Hiki2MW::Converter.new(source).convert
  end
end
