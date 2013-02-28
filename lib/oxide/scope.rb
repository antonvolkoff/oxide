module Oxide
  class Parser
    class Scope
      attr_accessor :parent

      attr_accessor :name

      attr_accessor :block_name

      attr_reader :scope_name
      attr_reader :ivars

      attr_reader :type

      attr_accessor :defines_defn
      attr_accessor :defines_defs

      attr_accessor :mid

      # true if singleton def, false otherwise
      attr_accessor :defs

      # used by modules to know what methods to donate to includees
      attr_reader :methods

      # uses parents super method
      attr_accessor :uses_super

      def initialize(type, parser)
        @parser  = parser
        @type    = type
        @locals  = []
        @temps   = []
        @args    = []
        @ivars   = []
        @parent  = nil
        @queue   = []
        @unique  = "a"
        @while_stack = []

        @defines_defs = false
        @defines_defn = false

        @methods  = []

        @uses_block = false

        # used by classes to store all ivars used in direct def methods
        @proto_ivars = []
      end

      def class_scope?
        @type == :class or @type == :module
      end

      def class?
        @type == :class
      end

      def module?
        @type == :module
      end

      def top?
        @type == :top
      end

      def iter?
        @type == :iter
      end

      def to_vars
        vars = @locals.map { |l| "#{l[0]} #{l[1]}" }
        vars.push *@temps
        current_self = @parser.current_self

        iv = ivars.map do |ivar|
         "if (#{current_self}#{ivar} == null) #{current_self}#{ivar} = nil;\n"
        end

        indent = @parser.parser_indent
        res = vars.empty? ? '' : "#{vars.join ', '};"
        str = ivars.empty? ? res : "#{res}\n#{indent}#{iv.join indent}"

        if class? and !@proto_ivars.empty?
          pvars = @proto_ivars.map { |i| "#{proto}#{i}"}.join(' = ')
          "%s\n%s%s = nil;" % [str, indent, pvars]
        else
          str
        end
      end

      def new_temp
        return @queue.pop unless @queue.empty?

        tmp = "_#{@unique}"
        @unique = @unique.succ
        @temps << tmp
        tmp
      end

      def queue_temp(name)
        @queue << name
      end

      def add_local(local)
        return if has_local? local

        @locals << local
      end

      def has_local?(local)
        return true if @locals.include? local or @args.include? local
        return @parent.has_local?(local) if @parent and @type == :iter

        false
      end
    end
  end
end