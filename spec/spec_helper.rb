require 'oxide'

module Kernel
  def oxide_parse(str)
    Oxide::Grammar.new.parse str, '(string)'
  end

  def oxide_sexp(str)
    Oxide::Grammar.new.parse str, '(string)'
  end

  def oxide_code(str)
    code = Oxide::Parser.new.parse str
  end

  def in_main(str)
    "int main(int argc, char **argv) {   \n  #{str}\n }"
  end
end

RSpec.configure do |config|
  # Use color in STDOUT
  config.color_enabled = true

  # Use color not only in STDOUT but also in pagers and files
  config.tty = true

  # Use the specified formatter
  config.formatter = :documentation # :progress, :html, :textmate

  config.treat_symbols_as_metadata_keys_with_true_values = true
end