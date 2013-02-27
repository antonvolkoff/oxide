require 'spec_helper'

describe "Strings" do
  it 'should parse an empty strigs' do
    oxide_parse('""').should == [:str, ""]
    oxide_parse("''").should == [:str, ""]
  end

  it 'should parse a simple string without interpolation' do
    oxide_parse('"foo # { } bar"').should == [:str, "foo # { } bar"]
  end

  it 'should not interpolate strings with single quotes' do
    oxide_parse("'\#{foo}'").should == [:str, "\#{foo}"]
    oxide_parse("'\#@foo'").should == [:str, "\#@foo"]
    oxide_parse("'\#$foo'").should == [:str, "\#$foo"]
    oxide_parse("'\#@@foo'").should == [:str, "\#@@foo"]
  end

  it 'should interpolate strings with double quotes' do
    oxide_parse('"#{foo}"').should == [:dstr, "", [:evstr, [:call, nil, :foo, [:arglist]]]]
    oxide_parse('"#@foo"').should == [:dstr, "", [:evstr, [:ivar, :@foo]]]
    oxide_parse('"#$foo"').should == [:dstr, "", [:evstr, [:gvar, :$foo]]]
    oxide_parse('"#@@foo"').should == [:dstr, "", [:evstr, [:cvar, :@@foo]]]
  end

  it 'should allow underscore for variables interpolation' do
    oxide_parse('"#@foo_bar"').should == [:dstr, "", [:evstr, [:ivar, :@foo_bar]]]
    oxide_parse('"#$foo_bar"').should == [:dstr, "", [:evstr, [:gvar, :$foo_bar]]]
    oxide_parse('"#@@foo_bar"').should == [:dstr, "", [:evstr, [:cvar, :@@foo_bar]]]
  end

  describe '%Q constructions' do
    it "should use '[', '(' or '{' matching pairs for string boundry" do
      oxide_parse('%Q{foo}').should == [:str, "foo"]
      oxide_parse('%Q[foo]').should == [:str, "foo"]
      oxide_parse('%Q(foo)').should == [:str, "foo"]
    end

    it "should parse empty strings" do
      oxide_parse('%Q{}').should == [:str, ""]
      oxide_parse('%Q[]').should == [:str, ""]
      oxide_parse('%Q()').should == [:str, ""]
    end

    it "should allow interpolation" do
      oxide_parse('%Q(#{foo})').should == [:dstr, "", [:evstr, [:call, nil, :foo, [:arglist]]]]
      oxide_parse('%Q[#{foo}]').should == [:dstr, "", [:evstr, [:call, nil, :foo, [:arglist]]]]
      oxide_parse('%Q{#{foo}}').should == [:dstr, "", [:evstr, [:call, nil, :foo, [:arglist]]]]
    end

    it "should allow variables interpolation" do
      oxide_parse('%Q{#@foo}').should == [:dstr, "", [:evstr, [:ivar, :@foo]]]
      oxide_parse('%Q{#$foo}').should == [:dstr, "", [:evstr, [:gvar, :$foo]]]
      oxide_parse('%Q{#@@foo}').should == [:dstr, "", [:evstr, [:cvar, :@@foo]]]
    end

    it "should match '{' and '}' pairs used to start string before ending match" do
      oxide_parse('%Q{{}}').should == [:str, "{}"]
      oxide_parse('%Q{foo{bar}baz}').should == [:str, "foo{bar}baz"]
      oxide_parse('%Q{{foo}bar}').should == [:str, "{foo}bar"]
      oxide_parse('%Q{foo{bar}}').should == [:str, "foo{bar}"]
      oxide_parse('%Q{foo#{bar}baz}').should == [:dstr, "foo", [:evstr, [:call, nil, :bar, [:arglist]]], [:str, "baz"]]
      oxide_parse('%Q{a{b{c}d{e}f}g}').should == [:str, "a{b{c}d{e}f}g"]
      oxide_parse('%Q{a{b{c}#{foo}d}e}').should == [:dstr, "a{b{c}", [:evstr, [:call, nil, :foo, [:arglist]]], [:str, "d}e"]]
    end

    it "should match '(' and ')' pairs used to start string before ending match" do
      oxide_parse('%Q(())').should == [:str, "()"]
      oxide_parse('%Q(foo(bar)baz)').should == [:str, "foo(bar)baz"]
      oxide_parse('%Q((foo)bar)').should == [:str, "(foo)bar"]
      oxide_parse('%Q(foo(bar))').should == [:str, "foo(bar)"]
      oxide_parse('%Q(foo#{bar}baz)').should == [:dstr, "foo", [:evstr, [:call, nil, :bar, [:arglist]]], [:str, "baz"]]
      oxide_parse('%Q(a(b(c)d(e)f)g)').should == [:str, "a(b(c)d(e)f)g"]
      oxide_parse('%Q(a(b(c)#{foo}d)e)').should == [:dstr, "a(b(c)", [:evstr, [:call, nil, :foo, [:arglist]]], [:str, "d)e"]]
    end

    it "should match '[' and ']' pairs used to start string before ending match" do
      oxide_parse('%Q[[]]').should == [:str, "[]"]
      oxide_parse('%Q[foo[bar]baz]').should == [:str, "foo[bar]baz"]
      oxide_parse('%Q[[foo]bar]').should == [:str, "[foo]bar"]
      oxide_parse('%Q[foo[bar]]').should == [:str, "foo[bar]"]
      oxide_parse('%Q[foo#{bar}baz]').should == [:dstr, "foo", [:evstr, [:call, nil, :bar, [:arglist]]], [:str, "baz"]]
      oxide_parse('%Q[a[b[c]d[e]f]g]').should == [:str, "a[b[c]d[e]f]g"]
      oxide_parse('%Q[a[b[c]#{foo}d]e]').should == [:dstr, "a[b[c]", [:evstr, [:call, nil, :foo, [:arglist]]], [:str, "d]e"]]
    end

    it "should correctly parse block braces within interpolations" do
      oxide_parse('%Q{#{each { nil } }}').should == [:dstr, "", [:evstr, [:iter, [:call, nil, :each, [:arglist]], nil, [:nil]]]]
    end

    it "should parse other Qstrings within interpolations" do
      oxide_parse('%Q{#{ %Q{} }}').should == [:dstr, "", [:evstr, [:str, ""]]]
    end
  end

  describe "character shortcuts" do
    it "should produce a string sexp" do
      oxide_parse("?a").should == [:str, "a"]
      oxide_parse("?&").should == [:str, "&"]
    end
  end
end