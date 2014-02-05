module CL

# Transforms existing math ops
module FoldMathOp

  MATH_N_ARY_FUNCS = [
    :+, :-,
    :*, :/,
    :and, :or,
    :'bitwise-and',
    :'bitwise-or',
    :'bitwise-xor'
  ]

  MATH_BINARY_FUNCS = [
    :'bitwise-shift',
    :'remainder'
  ]

  MATH_UNARY_FUNCS = [
    :'bitwise-not',
    :not,
    :-
  ]

  MATH_FUNCS = MATH_N_ARY_FUNCS + MATH_BINARY_FUNCS + MATH_UNARY_FUNCS

  IF_NUMBER = -> (n) { n.kind_of?(Numeric) }

  def unary_op(expr)
    return nil unless expr.length == 2 && MATH_UNARY_FUNCS.include?(expr[0])

    sym = expr[0]

    if sym == :not && !(expr[1].kind_of?(Symbol) || expr[1].kind_of?(Expr))
      return !expr[1]
    end

    return nil unless IF_NUMBER[expr.last]

    case sym
    when :- then -expr.last
    when :'bit-not' then ~expr.last
    end
  end

  def binary_op(expr)
    return nil unless expr.length == 3 && MATH_BINARY_FUNCS.include?(expr[0])
    operands = expr[1..-1]
    return nil unless operands.all?(&IF_NUMBER)

    sym = expr[0]

    case sym
    when :'bit-shift'
      case
      when expr[2] > 0 then expr[1] << expr[2]
      when expr[2] < 0 then expr[1] >> expr[2]
      else expr[1]
      end
    when :'bit-xor' then   expr[1] ^ expr[2]
    when :'remainder' then expr[1] % expr[2]
    end
  end

  def n_ary_op(expr)
    return nil unless expr.length >= 1 && MATH_N_ARY_FUNCS.include?(expr[0])

    sym =
      case expr[0]
      when :'bit-and' then :&
      when :'bit-or' then :|
      when :'bit-xor' then :'^'
      else expr[0]
      end

    result =
      case sym
      when :and
        expr.inner[1..-1].each do |k|
          break if k.kind_of?(Expr) || k.kind_of?(Symbol)
          return false if k == false
        end

        new_expr = SExpr.new(expr.inner.reject { |k| k == true })

        if new_expr.length == 2
          new_expr[1]
        else
          new_expr
        end

      when :or
        expr.inner[1..-1].each do |k|
          break if k.kind_of?(Expr) || k.kind_of?(Symbol)
          return k if k != false
        end

        new_expr = SExpr.new(expr.inner.reject { |k| k == false })

        if new_expr.length == 2
          new_expr[1]
        else
          new_expr
        end
      end

    if result.nil?
      return nil unless expr.count(&IF_NUMBER) > 1

      result =
        case sym
        when :+, :*, :|, :&, :^ # commutative operators
          new_expr = SExpr.new(expr.inner)
          new_expr.delete_if(&IF_NUMBER) << expr.select(&IF_NUMBER).reduce(sym)

        when :-, :/ # non-commutative operators
          new_expr = expr[1..-1].each_with_object(SExpr.new([expr[0]])) do |elem, newexpr|
            last = newexpr.last

            if last.kind_of?(Numeric) && elem.kind_of?(Numeric)
              elem =
                case sym
                when :/ then last / elem
                when :- then last - elem
                end
              newexpr.pop
            end

            newexpr << elem
          end
        end
    end

    if result.kind_of?(Expr) && result.length == 2 && result[1].kind_of?(Numeric)
      result[1]
    else
      result unless expr == result
    end
  end

  def [](expr)
    return nil unless expr.kind_of?(SExpr)
    return nil unless expr[0].kind_of?(Symbol)
    return nil unless MATH_FUNCS.include?(expr[0])

    r = n_ary_op(expr)
    if r.nil?
      r = binary_op(expr)
      r = unary_op(expr) if r.nil?
    end
    r
  end

  extend self

end # FoldMathOp

end # CL
