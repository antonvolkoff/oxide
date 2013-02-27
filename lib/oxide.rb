require "oxide/parser"
require "oxide/version"

# Oxide is ruby to c++ pre-compiler.
module Oxide
  # Parse given string of ruby into c++
  #
  #   Oxide.parse "puts 'hello world'"
  #   # => "printf('hello world\n');"
  #
  # @param [String] str ruby string to parse
  # @return [String] the resulting c++ code
  def self.parse(source)
    Parser.new.parse source
  end
end
