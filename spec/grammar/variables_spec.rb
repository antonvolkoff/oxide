require 'spec_helper'

describe 'Variables' do
  describe 'Local variables' do
    it "should return an s(:lasgn)" do
      oxide_parse("a = 1").should == [:lasgn, :a, [:lit, 1]]
      oxide_parse("a = 1; b = 2").should == [:block, [:lasgn, :a, [:lit, 1]], [:lasgn, :b, [:lit, 2]]]
    end
  end

  describe 'Instance variables' do
    it 'should return an s(:ivar)' do
      oxide_parse("@a").should == [:ivar, :@a]
      oxide_parse("@A").should == [:ivar, :@A]
      oxide_parse("@class").should == [:ivar, :@class]
    end

    it "should return s(:iasgn) on assignment" do
      oxide_parse("@a = 1").should == [:iasgn, :@a, [:lit, 1]]
      oxide_parse("@A = 1").should == [:iasgn, :@A, [:lit, 1]]
      oxide_parse("@class = 1").should == [:iasgn, :@class, [:lit, 1]]
    end
  end

  describe 'Global variables' do
    it "should be returned as s(:gvar)" do
      oxide_parse("$foo").should == [:gvar, :$foo]
      oxide_parse("$:").should == [:gvar, :$:]
    end

    it "should return s(:gasgn) on assignment" do
      oxide_parse("$foo = 1").should == [:gasgn, :$foo, [:lit, 1]]
      oxide_parse("$: = 1").should == [:gasgn, :$:, [:lit, 1]]
    end
  end

  describe "Class variables" do
    it "should always be returned as s(:cvar)" do
      oxide_parse("@@foo").should == [:cvar, :@@foo]
    end

    it "should return s(:cvdecl) on assignment" do
      oxide_parse("@@foo = 100").should == [:cvdecl, :@@foo, [:lit, 100]]
    end
  end

  describe "Constants" do
    it "should always become a s(:const)" do
      oxide_parse("FOO").should == [:const, :FOO]
      oxide_parse("BAR").should == [:const, :BAR]
    end

    it "should return s(:cdecl) on assignment" do
      oxide_parse("FOO = 1").should == [:cdecl, :FOO, [:lit, 1]]
      oxide_parse("FOO = BAR").should == [:cdecl, :FOO, [:const, :BAR]]
    end
  end
end