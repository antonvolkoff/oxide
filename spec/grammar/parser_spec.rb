require 'spec_helper'

describe Oxide::Parser do
  it 'should parse simple ruby values' do
    oxide_code('3.142').should == in_main("return 3.142;")
    oxide_code('123e1').should == in_main("return 1230.0;")
    oxide_code('123E+10').should == in_main("return 1230000000000.0;")
    # oxide_code('123e-9').should == 0.000000123
    # oxide_code('false').should == false
    # oxide_code('true').should == true
    # oxide_code('nil').should == nil
  end
end