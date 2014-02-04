module Enumerable
  def include_any?(*args)
    args.any? { |i| self.include?(i) }
  end

  def include_all?(*args)
    args.all? { |i| self.include?(i) }
  end

  def include_none?(*args)
    args.none? { |i| self.include?(i) }
  end

  # Maps all objects in the Enumerable to the block and returns the first
  # non-nil result, or nil if no result applied.
  def select_first(&block)
    if block_given?
      result = nil
      begin
        each { |obj|
          result = yield obj
          return result unless result.nil?
        }
      rescue StopIteration => ex
      end
      result
    else
      to_enum(:select_first)
    end
  end
end

class Array
  def head
    first
  end

  def tail
    self[1..-1]
  end
end
