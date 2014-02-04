require 'cowlips/init_by_block'
require 'cowlips/parser/expr'
require 'cowlips/funcdef'

module CL

class ClassDef < SExpr
  include InitByBlock

  NAME_FUNC_PAIR = -> (expr) {
    expr.kind_of?(SExpr) &&
    expr.length == 2 &&
    expr[0].kind_of?(Symbol) &&
    expr[1].kind_of?(FuncDef)
  }

  attr_accessor :inner, :name, :fields, :methods

  def initialize
    @inner = SExpr.new
    @name = ''
    @fields = SExpr.new
    @methods = []
    super

    yield self if block_given?

    rebind_children!
  end

  def rebind_children!
    super
    rebind_parent(@fields, self)
    rebind_parent(@methods, self)
  end

  def to_s
    "(def-type #{name} #{fields} #{inner}#{' ' if methods}#{methods.join ' '})"
  end

  class << self
    def [](expr)
      return nil unless expr.kind_of?(SExpr) && expr[0] == :'def-type'

      expect expr.length >= 4, "def-type takes at least three arguments (name, fields, ctor)"

      expect(
        expr[1].kind_of?(Symbol),
        "def-type's first argument must be a type name"
      )

      expect(
        expr[2].kind_of?(SExpr) && expr[2].all? { |k| k.kind_of?(Symbol) },
        "def-type's second argument must be a list of names"
        )

      expect(
        expr[3].kind_of?(SExpr),
        "def-type's ctor argument must be an S-expr for the ctor body"
        )

      warn "folding class def"

      ClassDef.new { |cx|
        cx.name      = expr[1]
        cx.fields    = expr[2]
        cx.methods   = expr.inner[4..-1]

        method_names = [cx.name, :"#{cx.name}?"] + cx.methods.map { |m| m[0] }
        puts method_names
        expect(
          method_names.uniq!.nil?,
          "All method names must be unique and not use the type's name"
          )

        expect(
          cx.methods.all?(&NAME_FUNC_PAIR),
          "All further arguments to def-type must be name-function pairs"
          )

        cx.methods.map! do |m|
          SExpr.new([
            m[0], # name
            FuncDef.new { |fx|
              fx.arguments = SExpr.new(m[1].arguments.inner).unshift(:this)
              fx.inner = [*m[1].inner]
            }
          ])
        end

        cx.inner = FuncDef.new { |fx|
          fx.arguments = cx.fields[0..-1].unshift(:this)
          fx.inner     = [expr[3]]
        }
      }
    end
  end
end

end