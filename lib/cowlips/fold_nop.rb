module CL

module FoldNop

  class << self

    def [](expr)
      SExpr.new if expr == :nop
    end

  end

end # FoldNop

end # CL