require 'cowlips/classdef'
require 'cowlips/fold_math'
require 'cowlips/fold_nop'

require 'set'

module CL

EXPR_FOLDS = [
  FoldNop,
  FoldMathOp,
  FuncDef,
  ClassDef,         # (class …)
  ->(expr) { expr } # preserve expr
]

def flat?(expr)
  !expr.kind_of?(Expr) || expr.none? { |i| i.kind_of?(Expr) }
end

def rebind_parent(expr, parent)
  if expr.kind_of? Expr
    expr.parent = parent

    if expr.respond_to?(:rebind_children!)
      expr.rebind_children!
    elsif expr.inner.respond_to? :each
      expr.inner.each { |subexpr|
        if subexpr.kind_of? Expr
          subexpr.parent = expr
          rebind_parent(subexpr, expr)
        end
      }
    elsif expr.inner.kind_of? Expr
      expr.inner.parent = expr
    end
  elsif expr.respond_to? :each
    expr.each { |i| rebind_parent(i, parent) }
  end
end

def fold_inner(expr, folded)
  expr.map! { |e| fold(e, folded) } if expr.kind_of?(Expr) && expr.respond_to?(:map!)
  expr
end

def fold(expr, folded = nil)
  return expr if expr.nil?

  if folded && folded.include?(expr.__id__)
    return expr
  end

  root = folded == nil

  folded ||= Set.new
  folded << expr.__id__ if expr.kind_of?(Expr)

  fold_inner(expr, folded)

  expr = EXPR_FOLDS.reduce(expr) do |ex, type|
    folded_expr = type[ex]
    folded_expr = ex if folded_expr.nil?
    fold_inner(folded_expr, folded)
  end

  folded << expr.__id__ if expr.kind_of?(Expr)

  rebind_parent(expr, nil) if root

  expr
rescue
  err "Error with expr"
  puts expr.inspect
  raise
end

end
