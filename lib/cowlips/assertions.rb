module CL

module Assertions
  def expect(*args, &block)
    test = block_given? ? yield() : args.unshift

    message = args.length >= 2 ? args[1] : args[0]

    if !test
      err "Expectations weren't met: #{message}"
      raise *args
    end

    test
  end

  def stop_error(*args)
    begin
      yield
    rescue StopIteration => ex
      err "StopIteration caught during stop_error"
      if args.length
        if args.length >= 2
          err args[1]
        elsif args.length == 1
          err args[0]
        end
        raise *args
      else
        raise RuntimeError, "StopIteration caught during stop_error"
      end
    end
  end

  extend self
end # Assertions

include Assertions
extend Assertions

end # CL
