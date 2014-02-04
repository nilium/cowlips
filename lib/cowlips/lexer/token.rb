
module CL

class Token
  attr_reader *%i[kind value position line column]

  class << self
    alias_method :[], :new
  end

  def initialize(kind, value, position, line, column, lexer)
    @kind       = kind
    @value      = value
    @position   = position
    @line       = line
    @column     = column
    @lexer      = lexer
  end

  def mark
    __mark.call
    self
  end

  def method_missing(m, *args)
    id_s = m.to_s
    if id_s.end_with?('?')
      id_s = id_s.chomp!('?').to_sym
      kind == id_s.to_sym
    else
      raise NoMethodError
    end
  end

  def number?
    integer? || float? || hexnum? || octnum? || binnum?
  end

  def to_object
    to_bool || to_num || to_s
  end

  def to_bool
    case kind
    when :true then true
    when :false then false
    end
  end

  def to_num
    case kind
    when :integer then value.to_i(10)
    when :float then value.to_f
    when :hexnum then value[2..-1].to_i(16)
    when :octnum then value[2..-1].to_i(8)
    when :binnum then value[2..-1].to_i(2)
    end
  end

  def to_s
    case kind
    when :regexp then eval(value[1..-1])
    when :string then eval(value)
    end
  end
end

end
