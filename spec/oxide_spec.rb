require 'spec_helper'

describe Oxide do
  def should_parse_example(name)
    Oxide.parse(ruby_fixture(name)).should == cpp_fixture(name)
  end

  it 'should parse example #1: method definition' do
    should_parse_example('example_1')
  end

  it 'should parse example #2: method calling' do
    should_parse_example('example_2')
  end
end