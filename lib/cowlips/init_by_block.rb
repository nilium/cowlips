module CL

module InitByBlock

  def initialize(*args)
    super(*args)
    yield self if block_given?
  end

end # InitByBlock

end # CL