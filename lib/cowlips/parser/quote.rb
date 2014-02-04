require 'cowlips/parser/expr'

module CL

class CL::QuotedExpr
  include Expr
  include Enumerable

  def initialize(inner = nil)
    @inner = inner
  end

  def inner
    @inner
  end

  def inner=(value)
    @inner =
      case Value
      when Array then value[0]
      else value
      end
  end

  def length
    1
  end

  def count(*args)
    if block_given?
      yield(@inner) ? 1 : 0
    elsif args.length == 1
      @inner == args[0] ? 1 : 0
    elsif args.length > 1
      raise ArgumentError
    else
      @inner ? 1 : 0
    end
  end

  def each
    if block_given?
      yield @inner
      self
    else
      to_enum(:each)
    end
  end

  def map
    if block_given?
      self.class.new(yield @inner)
    else
      to_enum(:map)
    end
  end

  def map!
    if block_given?
      @inner = yield @inner
    else
      to_enum(:map!)
    end
  end

  def select
    if block_given?
      self.class.new(yield(@inner) && @inner)
    else
      to_enum(:select)
    end
  end

  def select!
    if block_given?
      keep = yield(@inner)
      @inner = keep && @inner
      self unless keep
    else
      to_enum(:select!)
    end
  end

  def reject
    if block_given?
      self.class.new(!yield(@inner) && @inner)
    else
      to_enum(:reject)
    end
  end

  def reject!
    if block_given?
      keep = !yield(@inner)
      @inner = keep && @inner
      self unless keep
    else
      to_enum(:reject!)
    end
  end

  def keep_if
    if block_given?
      keep = yield(@inner)
      @inner = keep && @inner
      self
    else
      to_enum(:keep_if)
    end
  end

  def delete_if
    if block_given?
      keep = !yield(@inner)
      @inner = keep && @inner
      self
    else
      to_enum(:delete_if)
    end
  end

  def to_s
    "'#{inner.to_s}"
  end

  def tail
    []
  end

  def head
    @inner
  end

  def [](index)
    case index
    when Range then Quote.new(self[index.first])
    else [@inner][index]
    end
  end

  def []=(index, v)
    temp = [@inner]
    temp[index] = v
    @inner = temp[0]
  end
end # QuotedExpr

end # CL
