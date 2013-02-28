require 'spec_helper'

describe 'Method calls' do
  it "should use 'nil' for calls without a receiver" do
    oxide_parse("foo").should == [:call, nil, :foo, [:arglist]]
    oxide_parse("foo()").should == [:call, nil, :foo, [:arglist]]
  end

  it "should always have an arglist when not passed any arguments" do
    oxide_parse("foo").should == [:call, nil, :foo, [:arglist]]
    oxide_parse("self.foo").should == [:call, [:self], :foo, [:arglist]]
    oxide_parse("foo()").should == [:call, nil, :foo, [:arglist]]
    oxide_parse("self.foo()").should == [:call, [:self], :foo, [:arglist]]
  end

  it "appends all arguments onto arglist" do
    oxide_parse("foo 1").should == [:call, nil, :foo, [:arglist, [:lit, 1]]]
    oxide_parse("foo 1, 2").should == [:call, nil, :foo, [:arglist, [:lit, 1], [:lit, 2]]]
    oxide_parse("foo 1, *2").should == [:call, nil, :foo, [:arglist, [:lit, 1], [:splat, [:lit, 2]]]]
  end
end

describe "Operator calls" do
  it "should optimize math ops into operator calls" do
    oxide_parse("1 + 2").should == [:operator, :+, [:lit, 1], [:lit, 2]]
    oxide_parse("1 - 2").should == [:operator, :-, [:lit, 1], [:lit, 2]]
    oxide_parse("1 / 2").should == [:operator, :/, [:lit, 1], [:lit, 2]]
    oxide_parse("1 * 2").should == [:operator, :*, [:lit, 1], [:lit, 2]]
  end

  it "should parse all other operators into method calls" do
    oxide_parse("1 % 2").should == [:call, [:lit, 1], :%, [:arglist, [:lit, 2]]]
    oxide_parse("1 ** 2").should == [:call, [:lit, 1], :**, [:arglist, [:lit, 2]]]

    oxide_parse("+self").should == [:call, [:self], :+@, [:arglist]]
    oxide_parse("-self").should == [:call, [:self], :-@, [:arglist]]

    oxide_parse("1 | 2").should == [:call, [:lit, 1], :|, [:arglist, [:lit, 2]]]
    oxide_parse("1 ^ 2").should == [:call, [:lit, 1], :^, [:arglist, [:lit, 2]]]
    oxide_parse("1 & 2").should == [:call, [:lit, 1], :&, [:arglist, [:lit, 2]]]
    oxide_parse("1 <=> 2").should == [:call, [:lit, 1], :<=>, [:arglist, [:lit, 2]]]

    oxide_parse("1 < 2").should == [:call, [:lit, 1], :<, [:arglist, [:lit, 2]]]
    oxide_parse("1 <= 2").should == [:call, [:lit, 1], :<=, [:arglist, [:lit, 2]]]
    oxide_parse("1 > 2").should == [:call, [:lit, 1], :>, [:arglist, [:lit, 2]]]
    oxide_parse("1 >= 2").should == [:call, [:lit, 1], :>=, [:arglist, [:lit, 2]]]

    oxide_parse("1 == 2").should == [:call, [:lit, 1], :==, [:arglist, [:lit, 2]]]
    oxide_parse("1 === 2").should == [:call, [:lit, 1], :===, [:arglist, [:lit, 2]]]
    oxide_parse("1 =~ 2").should == [:call, [:lit, 1], :=~, [:arglist, [:lit, 2]]]

    oxide_parse("~1").should == [:call, [:lit, 1], :~, [:arglist]]
    oxide_parse("1 << 2").should == [:call, [:lit, 1], :<<, [:arglist, [:lit, 2]]]
    oxide_parse("1 >> 2").should == [:call, [:lit, 1], :>>, [:arglist, [:lit, 2]]]
  end

  it "optimizes +@ and -@ on numerics" do
    oxide_parse("+1").should == [:lit, 1]
    oxide_parse("-1").should == [:lit, -1]
  end
end

describe "Optional paren calls" do
  it "should correctly parse - and -@" do
    oxide_parse("x - 1").should == [:operator, :-, [:call, nil, :x, [:arglist]], [:lit, 1]]
    oxide_parse("x -1").should == [:call, nil, :x, [:arglist, [:lit, -1]]]
  end

  it "should correctly parse + and +@" do
    oxide_parse("x + 1").should == [:operator, :+, [:call, nil, :x, [:arglist]], [:lit, 1]]
    oxide_parse("x +1").should == [:call, nil, :x, [:arglist, [:lit, 1]]]
  end

  it "should correctly parse / and regexps" do
    oxide_parse("x / 500").should == [:operator, :/, [:call, nil, :x, [:arglist]], [:lit, 500]]
    oxide_parse("x /foo/").should == [:call, nil, :x, [:arglist, [:lit, /foo/]]]
  end

  it "should parse LPAREN_ARG correctly" do
    oxide_parse("x (1).y").should == [:call, nil, :x, [:arglist, [:call, [:lit, 1], :y, [:arglist]]]]
    oxide_parse("x(1).y").should == [:call, [:call, nil, :x, [:arglist, [:lit, 1]]], :y, [:arglist]]
  end
end

describe "Operator precedence" do
  it "should be raised with parentheses" do
   oxide_parse("(1 + 2) + (3 - 4)").should == [:operator, :+,
                                               [:operator, :+, [:lit, 1], [:lit, 2]],
                                               [:operator, :-, [:lit, 3], [:lit, 4]],
                                              ]
   oxide_parse("(1 + 2) - (3 - 4)").should == [:operator, :-,
                                               [:operator, :+, [:lit, 1], [:lit, 2]],
                                               [:operator, :-, [:lit, 3], [:lit, 4]],
                                              ]
   oxide_parse("(1 + 2) * (3 - 4)").should == [:operator, :*,
                                               [:operator, :+, [:lit, 1], [:lit, 2]],
                                               [:operator, :-, [:lit, 3], [:lit, 4]],
                                              ]
   oxide_parse("(1 + 2) / (3 - 4)").should == [:operator, :/,
                                               [:operator, :+, [:lit, 1], [:lit, 2]],
                                               [:operator, :-, [:lit, 3], [:lit, 4]],
                                              ]
  end
end
