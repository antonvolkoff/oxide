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
      @debug = true

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

    def mid_to_jsid(mid)
      if /\=|\+|\-|\*|\/|\!|\?|\<|\>|\&|\||\^|\%|\~|\[/ =~ mid.to_s
        "['$#{mid}']"
      else
        '.$' + mid
      end
    end

    # Generates code for top level sexp
    #
    def top(sexp)
      code = nil
      vars = []

      in_scope(:top) do
        code = process(s(:scope, sexp), :stmt)
        code = INDENT + @scope.to_vars + "\n" + code
      end

      "#{code}"
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

      puts "#{meth}(#{sexp.inspect}, #{level.inspect})" if @debug
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

    def main_method(sexp)
      puts "main_method(#{sexp.inspect})"
      return main_method(s(:nil)) unless sexp

      case sexp.first
      when :scope
        sexp[1] = main_method(sexp[1])
        sexp
      when :block
        if sexp.length > 1
          delete_indexes = []
          main_stmt = []

          # find out which elements needs to be deleted
          sexp.each_with_index do |s, i|
            # puts "#{i}: #{s.inspect} #{s.class}"
            if s.kind_of? Array and [:lasgn, :return].include? s.first
              delete_indexes << i
            end
          end

          # prepend elements main_stmt and delete those elements
          # in reverse order from sexp
          delete_indexes.reverse_each do |i|
            main_stmt.unshift(sexp[i])
            sexp.delete_at(i)
          end

          # place elements back into sexp inside :defn
          main_stmt.unshift(:block)
          sexp << s(:defn, :main, s(:args), s(:scope, main_stmt))
        else
          sexp << main_method(s(:nil))
        end
        sexp
      when :defn
        s(:block, sexp, s(:defn, :main, s(:args), s(:scope, s(:block, s(:nil))))).tap { |s|
          s.line = sexp.line
        }
      else
        s(:defn, :main, s(:args), s(:scope, s(:block, sexp))).tap { |s|
          s.line = sexp.line
        }
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
        sexp[1] = "return #{sexp[1]}" unless /return|;/ =~ sexp[1]
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

    # Returns type of the variable
    # TODO: add more types along the way
    def get_type(sexp)
      val = sexp[1]
      case val
      when Integer
        :int
      when Float
        :float
      else
        :void
      end
    end

    def find_inline_yield(stmt)
      found = nil
      case stmt.first
      when :js_return
        found = find_inline_yield stmt[1]
      when :array
        stmt[1..-1].each_with_index do |el, idx|
          if el.first == :yield
            found = el
            stmt[idx+1] = s(:js_tmp, '__yielded')
          end
        end
      when :call
        arglist = stmt[3]
        arglist[1..-1].each_with_index do |el, idx|
          if el.first == :yield
            found = el
            arglist[idx+1] = s(:js_tmp, '__yielded')
          end
        end
      end

      if found
        @scope.add_temp '__yielded' unless @scope.has_temp? '__yielded'
        s(:yasgn, '__yielded', found)
      end
    end

    def expression?(sexp)
      !STATEMENTS.include?(sexp.first)
    end

    #################
    ## Processors
    #################

    def process_scope(sexp, level)
      stmt = sexp.shift
      if stmt
        # INFO: Don't create returns for now. This needs a refactoring
        # stmt = returns stmt unless @scope.class_scope?
        stmt = main_method(stmt) if @scope.top?
        code = process stmt, :stmt
      else
        code = "nil"
      end

      code
    end

    # s(:c_return, sexp)
    def process_c_return(sexp, level)
      "#{process sexp.shift, :expr}\nreturn 0"
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

    # s(:call, recv, :mid, s(:arglist))
    # s(:call, nil, :mid, s(:arglist))
    def process_call(sexp, level)
      recv, meth, arglist, iter = sexp
      mid = mid_to_jsid meth.to_s

      case meth
      when :attr_reader, :attr_writer, :attr_accessor
        return handle_attr_optimize(meth, arglist[1..-1]) if @scope.class_scope?
      when :block_given?
        return js_block_given(sexp, level)
      when :alias_native
        return handle_alias_native(sexp) if @scope.class_scope?
      when :require
        path = arglist[1]

        if path and path[0] == :str
          @requires << path[1]
        end

        return ""
      when :respond_to?
        return handle_respond_to(sexp, level)
      end

      splat = arglist[1..-1].any? { |a| a.first == :splat }

      if Array === arglist.last and arglist.last.first == :block_pass
        arglist << s(:js_tmp, process(arglist.pop, :expr))
      elsif iter
        block   = iter
      end

      recv ||= s(:self)

      if block
        tmprecv = @scope.new_temp
      elsif splat and recv != [:self] and recv[0] != :lvar
        tmprecv = @scope.new_temp
      else # method_missing
       tmprecv = @scope.new_temp
      end

      args      = ""

      recv_code = process recv, :recv

      if @method_missing
        call_recv = s(:js_tmp, tmprecv || recv_code)
        arglist.insert 1, call_recv unless splat
        args = process arglist, :expr

        dispatch = if tmprecv
          "((#{tmprecv} = #{recv_code})#{mid} || $mm('#{ meth.to_s }'))"
        else
          "(#{recv_code}#{mid} || $mm('#{ meth.to_s }'))"
        end

        result = if splat
          "#{dispatch}.apply(#{process call_recv, :expr}, #{args})"
        else
          "#{dispatch}.call(#{args})"
        end
      else
        args = process arglist, :expr
        dispatch = tmprecv ? "(#{tmprecv} = #{recv_code})#{mid}" : "#{recv_code}#{mid}"
        result = splat ? "#{dispatch}.apply(#{tmprecv || recv_code}, #{args})" : "#{dispatch}(#{args})"
      end

      @scope.queue_temp tmprecv if tmprecv
      result
    end

    # s(:array [, sexp [, sexp]])
    def process_array(sexp, level)
      return '[]' if sexp.empty?

      code = ''
      work = []

      until sexp.empty?
        splat = sexp.first.first == :splat
        part  = process sexp.shift, :expr

        if splat
          if work.empty?
            code += (code.empty? ? part : ".concat(#{part})")
          else
            join  = "[#{work.join ', '}]"
            code += (code.empty? ? join : ".concat(#{join})")
            code += ".concat(#{part})"
          end
          work = []
        else
          work << part
        end
      end

      unless work.empty?
        join  = "[#{work.join ', '}]"
        code += (code.empty? ? join : ".concat(#{join})")
      end

      code
    end

    # s(:arglist, [arg [, arg ..]])
    def process_arglist(sexp, level)
      code = ''
      work = []

      until sexp.empty?
        splat = sexp.first.first == :splat
        arg   = process sexp.shift, :expr

        if splat
          if work.empty?
            if code.empty?
              code += "[].concat(#{arg})"
            else
              code += ".concat(#{arg})"
            end
          else
            join  = "[#{work.join ', '}]"
            code += (code.empty? ? join : ".concat(#{join})")
            code += ".concat(#{arg})"
          end

          work = []
        else
          work.push arg
        end
      end

      unless work.empty?
        join  = work.join ', '
        code += (code.empty? ? join : ".concat([#{join}])")
      end

      code
    end

    # s(:self)  # => this
    def process_self(sexp, level)
      current_self
    end

    # s(:lasgn, :lvar, rhs)
    def process_lasgn(sexp, level)
      lvar = sexp[0]
      rhs  = sexp[1]
      lvar = "#{lvar}$".to_sym if RESERVED.include? lvar.to_s
      ltype = get_type(rhs)
      @scope.add_local [ltype, lvar]
      res = "#{lvar} = #{process rhs, :expr};"
      level == :recv ? "(#{res})" : res
    end

    # s(:defn, mid, s(:args), s(:scope))
    def process_defn(sexp, level)
      mid = sexp[0]
      args = sexp[1]
      stmts = sexp[2]
      cpp_def nil, mid, args, stmts, sexp.line, sexp.end_line
    end

    # s(:defs, recv, mid, s(:args), s(:scope))
    def process_defs(sexp, level)
      recv = sexp[0]
      mid  = sexp[1]
      args = sexp[2]
      stmts = sexp[3]
      cpp_def recv, mid, args, stmts, sexp.line, sexp.end_line
    end

    def cpp_def(recvr, mid, args, stmts, line, end_line)
      code = ''
      return_type = ''

      if mid == "main"
        return_type = 'int'
      else
        return_type = 'void'
      end

      code += "#{return_type} #{mid}()\n{"
      indent do
        in_scope(:def) do
          stmt_code = "\n#@indent" + process(stmts, :stmt)
          code += stmt_code
        end
      end
      code += "\n}"

      # if recvr
      #   @scope.defines_defs = true
      #   smethod = true if @scope.class_scope? && recvr.first == :self
      #   recv = process(recvr, :expr)
      # else
      #   @scope.defines_defn = true
      #   recv = current_self
      # end

      # code = ''
      # params = nil
      # scope_name = nil
      # uses_super = nil
      # uses_splat = nil

      # # opt args if last arg is sexp
      # opt = args.pop if Array === args.last

      # argc = args.length - 1

      # # block name &block
      # if args.last.to_s.start_with? '&'
      #   block_name = args.pop.to_s[1..-1].to_sym
      #   argc -= 1
      # end

      # # splat args *splat
      # if args.last.to_s.start_with? '*'
      #   uses_splat = true
      #   if args.last == :*
      #     #args[-1] = splat
      #     argc -= 1
      #   else
      #     splat = args[-1].to_s[1..-1].to_sym
      #     args[-1] = splat
      #     argc -= 1
      #   end
      # end

      # args << block_name if block_name # have to re-add incase there was a splat arg

      # if @arity_check
      #   arity_code = arity_check(args, opt, uses_splat, block_name, mid) + "\n#{INDENT}"
      # end

      # indent do
      #   in_scope(:def) do
      #     @scope.mid  = mid
      #     @scope.defs = true if recvr

      #     if block_name
      #       @scope.uses_block!
      #     end

      #     yielder = block_name || '__yield'
      #     @scope.block_name = yielder

      #     params = process args, :expr
      #     stmt_code = "\n#@indent" + process(stmts, :stmt)

      #     if @scope.uses_block?
      #       # CASE 1: no args - only the block
      #       if argc == 0 and !splat
      #         # add param name as a function param, to make it cleaner
      #         # params = yielder
      #         code += "if (typeof(#{yielder}) !== 'function') { #{yielder} = nil }"
      #       # CASE 2: we have a splat - use argc to get splat args, then check last one
      #       elsif splat
      #         @scope.add_temp yielder
      #         code += "#{splat} = __slice.call(arguments, #{argc});\n#{@indent}"
      #         code += "if (typeof(#{splat}[#{splat}.length - 1]) === 'function') { #{yielder} = #{splat}.pop(); } else { #{yielder} = nil; }\n#{@indent}"
      #       # CASE 3: we have some opt args
      #       elsif opt
      #         code += "var BLOCK_IDX = arguments.length - 1;\n#{@indent}"
      #         code += "if (typeof(arguments[BLOCK_IDX]) === 'function' && arguments[BLOCK_IDX]._s !== undefined) { #{yielder} = arguments[BLOCK_IDX] } else { #{yielder} = nil }"
      #         lastopt = opt[-1][1]
      #         opt[1..-1].each do |o|
      #           id = process s(:lvar, o[1]), :expr
      #           if o[2][2] == :undefined
      #             code += ("if (%s === %s && typeof(%s) === 'function') { %s = undefined; }" % [id, yielder, id, id])
      #           else
      #             code += ("if (%s == null || %s === %s) {\n%s%s\n%s}" %
      #                     [id, id, yielder, @indent + INDENT, process(o, :expre), @indent])
      #           end
      #         end

      #       # CASE 4: normal args and block
      #       else
      #         code += "if (typeof(#{yielder}) !== 'function') { #{yielder} = nil }"
      #       end
      #     else
      #       opt[1..-1].each do |o|
      #         next if o[2][2] == :undefined
      #         id = process s(:lvar, o[1]), :expr
      #         code += ("if (%s == null) {\n%s%s\n%s}" %
      #                   [id, @indent + INDENT, process(o, :expre), @indent])
      #       end if opt

      #       code += "#{splat} = __slice.call(arguments, #{argc});" if splat
      #     end

      #     code += stmt_code

      #     if @scope.uses_block? and !block_name
      #       params = params.empty? ? yielder : "#{params}, #{yielder}"
      #     end

      #     # Returns the identity name if identified, nil otherwise
      #     scope_name = @scope.identity

      #     uses_super = @scope.uses_super

      #     code = "#{arity_code}#@indent#{@scope.to_vars}" + code
      #   end
      # end

      # defcode = "#{"#{scope_name} = " if scope_name}function(#{params}) {\n#{code}\n#@indent}"

      # if recvr
      #   if smethod
      #     "#{ @scope.name }._defs('$#{mid}', #{defcode})"
      #   else
      #     "#{ recv }#{ jsid } = #{ defcode }"
      #   end
      # elsif @scope.class_scope?
      #   @scope.methods << "$#{mid}"
      #   if uses_super
      #     @scope.add_temp uses_super
      #     uses_super = "#{uses_super} = #{@scope.proto}#{jsid};\n#@indent"
      #   end
      #   "#{uses_super}#{ @scope.proto }#{jsid} = #{defcode}"
      # elsif @scope.type == :iter
      #   "def#{jsid} = #{defcode}"
      # elsif @scope.type == :top
      #   "#{ current_self }#{ jsid } = #{ defcode }"
      # else
      #   "def#{jsid} = #{defcode}"
      # end
    end

    def process_args(exp, level)
      args = []

      until exp.empty?
        a = exp.shift.to_sym
        next if a.to_s == '*'
        a = "#{a}$".to_sym if RESERVED.include? a.to_s
        @scope.add_arg a
        args << a
      end

      args.join ', '
    end

    def process_block(sexp, level)
      result = []
      sexp << s(:nil) if sexp.empty?

      until sexp.empty?
        stmt = sexp.shift
        type = stmt.first

        # find any inline yield statements
        if yasgn = find_inline_yield(stmt)
          result << "#{process(yasgn, level)}"
        end

        expr = expression?(stmt) and LEVEL.index(level) < LEVEL.index(:list)
        code = process(stmt, level)
        result << (expr ? "#{code}" : code) unless code == ""
      end

      result.join(@scope.class_scope? ? "\n\n#@indent" : "\n#@indent")
    end

    def process_defined(sexp, level)
      part = sexp[0]
      case part[0]
      when :self
        "self".inspect
      when :nil
        "nil".inspect
      when :true
        "true".inspect
      when :false
        "false".inspect
      when :call
        mid = mid_to_jsid part[2].to_s
        recv = part[1] ? process(part[1], :expr) : current_self
        "(#{recv}#{mid} ? 'method' : nil)"
      when :xstr
        "(typeof(#{process part, :expression}) !== 'undefined')"
      when :colon2
        "false"
      else
        raise "bad defined? part: #{part[0]}"
      end
    end

    %w(true false nil).each do |name|
      define_method "process_#{name}" do |exp, level|
        name
      end
    end

    # s(:return [val])
    def process_return(sexp, level)
      val = process(sexp.shift || s(:nil), :expr)

      raise "Cannot return as an expression" unless level == :stmt
      "return #{val};"
    end
  end
end