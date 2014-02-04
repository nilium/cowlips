require 'cowlips/parser/expr'
require 'cowlips/enumerable'

module CL

class SExpr
  include Expr
  include Enumerable

  attr_accessor :inner

  def initialize(arg = nil)
    @inner =
      case arg
      when Array then arg[0..-1]
      when SExpr then arg.inner[0..-1]
      when nil then []
      else raise ArgumentError
      end
  end

  def length
    @inner.length
  end

  def count(*args, &block)
    if block_given?
      inner.count(&block)
    elsif args.length == 1
      inner.count(args[0])
    elsif args.length > 1
      raise ArgumentError
    else
      inner.count
    end
  end

  def each(&block)
    if block_given?
      @inner.each(&block)
      self
    else
      to_enum(:each)
    end
  end

  def map!(&block)
    if block_given?
      @inner.map!(&block)
      self
    else
      to_enum(:map!)
    end
  end

  def map(&block)
    if block_given?
      SExpr.new(@inner.map(&block))
    else
      to_enum(:map)
    end
  end

  def select(&block)
    if block_given?
      SExpr.new(@inner.select(&block))
    else
      to_enum(:select)
    end
  end

  def reject(&block)
    if block_given?
      SExpr.new(@inner.reject(&block))
    else
      to_enum(:reject)
    end
  end

  def select!(&block)
    if block_given?
      @inner.select!(&block)
      self
    else
      to_enum(:select!)
    end
  end

  def reject!(&block)
    if block_given?
      @inner.reject!(&block)
      self
    else
      to_enum(:reject!)
    end
  end

  def delete_if(&block)
    if block_given?
      @inner.delete_if(&block)
      self
    else
      to_enum(:delete_if)
    end
  end

  def keep_if(&block)
    if block_given?
      @inner.keep_if(&block)
      self
    else
      to_enum(:keep_if)
    end
  end

  def << (*args)
    @inner += args
    self
  end

  def tail
    self.class.new(@inner.tail)
  end

  def head
    @inner.head
  end

  def [](arg)
    case arg
    when Range then SExpr.new(@inner[arg])
    when Numeric then @inner[arg]
    else raise ArgumentError
    end
  end

  def []=(*args)
    @inner.send(:[]=, *args)
  end

  def unshift(*args)
    @inner.unshift(*args)
    self
  end

  def shift(*args)
    @inner.shift(*args)
  end

  def push(*args)
    @inner.push(*args)
    self
  end

  def last
    @inner.last
  end

  def pop(*args)
    @inner.pop(*args)
  end
end

end
