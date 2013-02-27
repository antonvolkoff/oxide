require 'spec_helper'

describe 'X-Strings' do
  it "should parse simple xstring as s(:xstr)" do
    oxide_parse("`foo`").should == [:xstr, "foo"]
  end

  it "should parse new lines within xstring" do
    oxide_parse("`\nfoo\n\nbar`").should == [:xstr, "\nfoo\n\nbar"]
  end

  it "should allow interpolation within xstring" do
    oxide_parse('`#{bar}`').should == [:dxstr, "", [:evstr, [:call, nil, :bar, [:arglist]]]]
    oxide_parse('`#{bar}#{baz}`').should == [:dxstr, "", [:evstr, [:call, nil, :bar, [:arglist]]], [:evstr, [:call, nil, :baz, [:arglist]]]]
  end

  it "should support ivar interpolation" do
    oxide_parse('`#@foo`').should == [:dxstr, "", [:evstr, [:ivar, :@foo]]]
    oxide_parse('`#@foo.bar`').should == [:dxstr, "", [:evstr, [:ivar, :@foo]], [:str, ".bar"]]
  end

  it "should support gvar interpolation" do
    oxide_parse('`#$foo`').should == [:dxstr, "", [:evstr, [:gvar, :$foo]]]
    oxide_parse('`#$foo.bar`').should == [:dxstr, "", [:evstr, [:gvar, :$foo]], [:str, ".bar"]]
  end

  it "should support cvar interpolation" do
    oxide_parse('`#@@foo`').should == [:dxstr, "", [:evstr, [:cvar, :@@foo]]]
  end

  it "should parse block braces within interpolations" do
    oxide_parse('`#{ each { nil } }`').should == [:dxstr, "", [:evstr, [:iter, [:call, nil, :each, [:arglist]], nil, [:nil]]]]
  end

  it "should parse xstrings within interpolations" do
    oxide_parse('`#{ `bar` }`').should == [:dxstr, "", [:evstr, [:xstr, "bar"]]]
  end

  it "should parse multiple levels of interpolation" do
    oxide_parse('`#{ `#{`bar`}` }`').should == [:dxstr, "", [:evstr, [:dxstr, "", [:evstr, [:xstr, "bar"]]]]]
  end

  describe "created using %x notation" do
    it "should use '[', '(' or '{' matching pairs for string boundry" do
      oxide_parse('%x{foo}').should == [:xstr, "foo"]
      oxide_parse('%x[foo]').should == [:xstr, "foo"]
      oxide_parse('%x(foo)').should == [:xstr, "foo"]
    end

    it "should parse empty strings" do
      oxide_parse('%x{}').should == [:xstr, ""]
      oxide_parse('%x[]').should == [:xstr, ""]
      oxide_parse('%x()').should == [:xstr, ""]
    end

    it "should allow interpolation" do
      oxide_parse('%x{#{foo}}').should == [:dxstr, "", [:evstr, [:call, nil, :foo, [:arglist]]]]
      oxide_parse('%x[#{foo}]').should == [:dxstr, "", [:evstr, [:call, nil, :foo, [:arglist]]]]
      oxide_parse('%x(#{foo})').should == [:dxstr, "", [:evstr, [:call, nil, :foo, [:arglist]]]]
    end

    it "should allow ivar, gvar and cvar interpolation" do
      oxide_parse('%x{#@foo}').should == [:dxstr, "", [:evstr, [:ivar, :@foo]]]
      oxide_parse('%x{#$foo}').should == [:dxstr, "", [:evstr, [:gvar, :$foo]]]
      oxide_parse('%x{#@@foo}').should == [:dxstr, "", [:evstr, [:cvar, :@@foo]]]
    end

    it "should match '{' and '}' pairs used to start string before ending match" do
      oxide_parse('%x{{}}').should == [:xstr, "{}"]
      oxide_parse('%x{foo{bar}baz}').should == [:xstr, "foo{bar}baz"]
      oxide_parse('%x{{foo}bar}').should == [:xstr, "{foo}bar"]
      oxide_parse('%x{foo{bar}}').should == [:xstr, "foo{bar}"]
      oxide_parse('%x{foo#{bar}baz}').should == [:dxstr, "foo", [:evstr, [:call, nil, :bar, [:arglist]]], [:str, "baz"]]
      oxide_parse('%x{a{b{c}d{e}f}g}').should == [:xstr, "a{b{c}d{e}f}g"]
      oxide_parse('%x{a{b{c}#{foo}d}e}').should == [:dxstr, "a{b{c}", [:evstr, [:call, nil, :foo, [:arglist]]], [:str, "d}e"]]
    end

    it "should match '(' and ')' pairs used to start string before ending match" do
      oxide_parse('%x(())').should == [:xstr, "()"]
      oxide_parse('%x(foo(bar)baz)').should == [:xstr, "foo(bar)baz"]
      oxide_parse('%x((foo)bar)').should == [:xstr, "(foo)bar"]
      oxide_parse('%x(foo(bar))').should == [:xstr, "foo(bar)"]
      oxide_parse('%x(foo#{bar}baz)').should == [:dxstr, "foo", [:evstr, [:call, nil, :bar, [:arglist]]], [:str, "baz"]]
      oxide_parse('%x(a(b(c)d(e)f)g)').should == [:xstr, "a(b(c)d(e)f)g"]
      oxide_parse('%x(a(b(c)#{foo}d)e)').should == [:dxstr, "a(b(c)", [:evstr, [:call, nil, :foo, [:arglist]]], [:str, "d)e"]]
    end

    it "should match '[' and ']' pairs used to start string before ending match" do
      oxide_parse('%x[[]]').should == [:xstr, "[]"]
      oxide_parse('%x[foo[bar]baz]').should == [:xstr, "foo[bar]baz"]
      oxide_parse('%x[[foo]bar]').should == [:xstr, "[foo]bar"]
      oxide_parse('%x[foo[bar]]').should == [:xstr, "foo[bar]"]
      oxide_parse('%x[foo#{bar}baz]').should == [:dxstr, "foo", [:evstr, [:call, nil, :bar, [:arglist]]], [:str, "baz"]]
      oxide_parse('%x[a[b[c]d[e]f]g]').should == [:xstr, "a[b[c]d[e]f]g"]
      oxide_parse('%x[a[b[c]#{foo}d]e]').should == [:dxstr, "a[b[c]", [:evstr, [:call, nil, :foo, [:arglist]]], [:str, "d]e"]]
    end

    it "should parse block braces within interpolations" do
      oxide_parse('%x{#{each { nil } }}').should == [:dxstr, "", [:evstr, [:iter, [:call, nil, :each, [:arglist]], nil, [:nil]]]]
    end

    it "should parse other Xstrings within interpolations" do
      oxide_parse('%x{#{ %x{} }}').should == [:dxstr, "", [:evstr, [:xstr, ""]]]
      oxide_parse('%x{#{ `` }}').should == [:dxstr, "", [:evstr, [:xstr, ""]]]
      oxide_parse('%x{#{ `foo` }}').should == [:dxstr, "", [:evstr, [:xstr, "foo"]]]
    end
  end

  describe "cannot be created with %X notation" do
    it "should not parse" do
      lambda {
        oxide_parse('%X{}')
      }.should raise_error(Exception)
    end
  end
end