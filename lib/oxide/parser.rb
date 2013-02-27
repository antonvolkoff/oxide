require 'oxide/lexer'
require 'oxide/grammar'
require 'oxide/scope'

module Oxide
  class Parser
    # Generated code is indented with two spaces on each scope
    INDENT = '  '
    LEVEL = [:stmt, :stmt_closure, :list, :expr, :recv]
    COMPARE = %w[< > <= >=]
    # Reserved c++ keywords - we cannot create variables with these names
    RESERVED = %w(
      alignas alignof and and_eq asm auto bitand bitor bool break case
      catch char char16_t char32_t class compl const constexpr const_cast
      continue decltype default delete do double dynamic_cast else
      enum explicit export extern false float for friend goto if inline
      int long mutable namespace new noexcept not not_eq nullptr operator
      or or_eq private protected public register reinterpret_cast
      return short signed sizeof static static_assert static_cast struct
      switch template this thread_local throw true try typedef typeid
      typename union unsigned using virtual void volatile wchar_t while
      xor xor_eq override final
    )
    STATEMENTS = [:xstr, :dxstr]

    # This does the actual parsing
    def parse(source, options = {})
      @grammer = Grammar.new
      @requires = []
      @line = 1
      @indent   = ''
      @unique   = 0

      top @grammer.parse(source, '(file)')
    end

    def parser_indent
      @indent
    end

    def s(*parts)
      sexp = Array.new(parts)
      sexp.line = @line
      sexp
    end

    # Generates code for top level sexp
    #
    def top(sexp)
      code = nil
      vars = []

      in_scope(:top) do
        indent {
          code = @indent + process(s(:scope, sexp), :stmt)
          # code = process(s(:scope, sexp), :stmt)
        }

        code = INDENT + @scope.to_vars + "\n" + code
        # code = @scope.to_vars + "\n" + code
      end

      "int main(int argc, char **argv) { #{code}\n }"
    end

    def in_scope(type)
      return unless block_given?

      parent = @scope
      @scope = Scope.new(type, self).tap { |s| s.parent = parent }
      yield @scope

      @scope = parent
    end

    def indent(&block)
      indent = @indent
      @indent += INDENT
      @space = "\n#@indent"
      res = yield
      @indent = indent
      @space = "\n#@indent"
      res
    end

    def process(sexp, level)
      type = sexp.shift
      meth = "process_#{type}"
      raise "Unsupported sexp: #{type}" unless respond_to? meth

      @line = sexp.line

      __send__ meth, sexp, level
    end

    # Returns the current value for 'self'. This will be native
    # 'this' for methods and blocks, and the class name for class
    # and module bodies.
    def current_self
      if @scope.class_scope?
        @scope.name
      elsif @scope.top?
        'self'
      elsif @scope.top?
        'self'
      elsif @scope.iter?
        'self'
      else # def
        'this'
      end
    end


    def returns(sexp)
      return returns s(:nil) unless sexp

      case sexp.first
      when :break, :next
        sexp
      when :yield
        sexp[0] = :returnable_yield
        sexp
      when :scope
        sexp[1] = returns sexp[1]
        sexp
      when :block
        if sexp.length > 1
          sexp[-1] = returns sexp[-1]
        else
          sexp << returns(s(:nil))
        end
        sexp
      when :when
        sexp[2] = returns(sexp[2])
        sexp
      when :rescue
        sexp[1] = returns sexp[1]
        sexp
      when :ensure
        sexp[1] = returns sexp[1]
        sexp
      when :while
        # sexp[2] = returns(sexp[2])
        sexp
      when :return
        sexp
      when :xstr
        sexp[1] = "return #{sexp[1]};" unless /return|;/ =~ sexp[1]
        sexp
      when :dxstr
        sexp[1] = "return #{sexp[1]}" unless /return|;|\n/ =~ sexp[1]
        sexp
      when :if
        sexp[2] = returns(sexp[2] || s(:nil))
        sexp[3] = returns(sexp[3] || s(:nil))
        sexp
      else
        s(:c_return, sexp).tap { |s|
          s.line = sexp.line
        }
      end
    end

    #################
    ## Processors
    #################

    def process_scope(sexp, level)
      stmt = sexp.shift
      if stmt
        stmt = returns stmt unless @scope.class_scope?
        code = process stmt, :stmt
      else
        code = "nil"
      end

      code
    end

    # s(:c_return, sexp)
    def process_c_return(sexp, level)
      "return #{process sexp.shift, :expr};"
    end

    # s(:lit, 1)
    # s(:lit, :foo)
    def process_lit(sexp, level)
      val = sexp.shift
      case val
      when Numeric
        level == :recv ? "(#{val.inspect})" : val.inspect
      when Symbol
        val.to_s.inspect
      when Regexp
        val == // ? /^/.inspect : val.inspect
      when Range
        @helpers[:range] = true
        "__range(#{val.begin}, #{val.end}, #{val.exclude_end?})"
      else
        raise "Bad lit: #{val.inspect}"
      end
    end
  end
end