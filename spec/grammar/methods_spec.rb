require 'spec_helper'

describe 'Methods definition' do
  describe "for normal definitions" do
    it "should return s(:defn)" do
      oxide_parse("def a; end").should == [:defn, :a, [:args], [:scope, [:block, [:nil]]]]
    end

    it "should add s(:nil) on an empty body" do
      oxide_parse("def foo; end").last.should == [:scope, [:block, [:nil]]]
    end
  end

  describe "for singleton definitions" do
    it "should return s(:defs)" do
      oxide_parse("def self.a; end").should == [:defs, [:self], :a, [:args], [:scope, [:block]]]
    end

    it "should not add s(:nil) on an empty body" do
      oxide_parse("def self.foo; end").last.should == [:scope, [:block]]
    end
  end

  describe "with normal args" do
    it "should list all args" do
      oxide_parse("def foo(a); end")[2].should == [:args, :a]
      oxide_parse("def foo(a, b); end")[2].should == [:args, :a, :b]
      oxide_parse("def foo(a, b, c); end")[2].should == [:args, :a, :b, :c]
    end
  end

  describe "with opt args" do
    it "should list all opt args as well as block with each lasgn" do
      oxide_parse("def foo(a = 1); end")[2].should == [:args, :a, [:block, [:lasgn, :a, [:lit, 1]]]]
      oxide_parse("def foo(a = 1, b = 2); end")[2].should == [:args, :a, :b, [:block, [:lasgn, :a, [:lit, 1]], [:lasgn, :b, [:lit, 2]]]]
    end

    it "should list lasgn block after all other args" do
      oxide_parse("def foo(a, b = 1); end")[2].should == [:args, :a, :b, [:block, [:lasgn, :b, [:lit, 1]]]]
      oxide_parse("def foo(b = 1, *c); end")[2].should == [:args, :b, :"*c", [:block, [:lasgn, :b, [:lit, 1]]]]
      oxide_parse("def foo(b = 1, &block); end")[2].should == [:args, :b, :"&block", [:block, [:lasgn, :b, [:lit, 1]]]]
    end
  end

  describe "with rest args" do
    it "should list rest args in place as a symbol with '*' prefix" do
      oxide_parse("def foo(*a); end")[2].should == [:args, :"*a"]
    end

    it "should use '*' as an arg name for rest args without a name" do
      oxide_parse("def foo(*); end")[2].should == [:args, :"*"]
    end
  end

  describe "with block arg" do
    it "should list block argument with the '&' prefix" do
      oxide_parse("def foo(&a); end")[2].should == [:args, :"&a"]
    end
  end
end