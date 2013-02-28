require 'spec_helper'

describe Oxide do
  it 'should parse simple ruby values' do
    # Oxide.parse('3.142').should == in_main("return 3.142;")
    # Oxide.parse('123e1').should == in_main("return 1230.0;")
    # Oxide.parse('123E+10').should == in_main("return 1230000000000.0;")
    # oxide_code('123e-9').should == 0.000000123
    # oxide_code('false').should == false
    # oxide_code('true').should == true
    # oxide_code('nil').should == nil
  end

  it 'should parse ruby variables', :wip do
    Oxide.parse('i = 0').should == "int main(int argc, char **argv) {   int i;\n  i = 0;\nreturn 0;\n }"
    Oxide.parse('pi = 3.142').should == "int main(int argc, char **argv) {   float pi;\n  pi = 3.142;\nreturn 0;\n }"
  end
end