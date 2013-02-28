require 'spec_helper'

describe Oxide do
  it 'should parse ruby integer variables' do
    Oxide.parse('i = 0').should == cpp_fixture('simple_integer')
    Oxide.parse('pi = 3.142').should == cpp_fixture('pi_float')
  end

  it 'should propely declare methods', :wip do
    puts oxide_sexp(ruby_fixture('test_method')).inspect
    Oxide.parse(ruby_fixture('test_method')).should == cpp_fixture('test_method')
  end

  it 'should parse method and variable', :wip do
    puts oxide_sexp(ruby_fixture('method_and_variable')).inspect
    Oxide.parse(ruby_fixture('method_and_variable')).should == cpp_fixture('method_and_variable')
  end
end