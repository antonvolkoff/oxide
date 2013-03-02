require 'spec_helper'

describe Oxide do
  it 'should parse example #1', :wip do
    Oxide.parse(ruby_fixture('example_1')).should == cpp_fixture('example_1')
  end
end