module CL

module Assertions
  def expect(test, *args)
    exception, message =
      if args.length >= 2
        [args[0], args[1]]
      else
        [RuntimeError, args[0]]
      end

    raise exception, message if !test
  end

  extend self
end # Assertions

include Assertions
extend Assertions

end # CL
