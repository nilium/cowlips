require 'cowlips/init_by_block'
require 'cowlips/parser/expr'

module CL

class FuncDef < SExpr
  attr_accessor :inner, :arguments

  def initialize
    info "init'ing function"
    @arguments = SExpr.new
    @inner = []
    super

    yield self if block_given?

    rebind_children!
  end

  def rebind_children!
    super
    rebind_parent(@arguments, self)
  end

  def to_s
    puts arguments
    puts inner.class
    puts arguments.class
    "(func #{arguments} #{inner.join ' '})"
  end

  class << self
    def [](expr)
      unless expr.kind_of?(SExpr) && expr[0] == :'func'
        return nil
      end

      expect expr.length >= 2, "func requires a parameter list"

      expect(
        expr[1].kind_of?(SExpr) && !expr[2].nil?,
        "func's first argument must be a list of parameter names"
        )

      FuncDef.new { |fx|
        fx.inner              = expr.inner[2..-1]
        fx.arguments          = SExpr.new(expr[1])
      }
    end
  end
end

end