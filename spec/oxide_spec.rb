require 'spec_helper'

describe Oxide do
  it 'should parse method and variable', :wip do
    puts oxide_sexp(ruby_fixture('method_and_variable')).inspect
    Oxide.parse(ruby_fixture('method_and_variable')).should == cpp_fixture('method_and_variable')
  end
end