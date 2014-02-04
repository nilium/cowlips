module CL

module Expr
  attr_accessor :parent

  def run(env: $LISP_ENV)
    raise NotImplementedError
  end

  def inner=(new_inner)
    raise NotImplementedError
  end

  def inner
    raise NotImplementedError
  end

  def to_s
    "(#{inner.map { |i| Regexp === i ? i.inspect : i.to_s }.join ' '})"
  end

  def rebind_children!
    rebind_parent(@inner, self)
  end
end # Expr

end # CL
