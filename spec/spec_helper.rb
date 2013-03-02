require 'oxide'

module Kernel
  def oxide_parse(str)
    oxide_sexp(str)
  end

  def oxide_sexp(str)
    Oxide::Grammar.new.parse str, '(string)'
  end

  def load_fixture(name, ext)
    File.open("#{File.dirname(__FILE__)}/fixtures/#{name}#{ext}", 'r').read
  end

  def cpp_fixture(name)
    load_fixture(name, '.cpp')
  end

  def ruby_fixture(name)
    load_fixture(name, '.rb')
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