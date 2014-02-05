require 'set'

module CL

IP_REG = 0
EBP_REG = 1
ESP_REG = 2
RETURN_REG = 3

class VMStack
  FIRST_ARG_BIT = 0x10
  FIRST_ARGUMENT_REGISTER = 4
  FIRST_VOLATILE_REGISTER = 12
  FIRST_TEMPORARY_REGISTER = 32
  RESERVED_REGISTER_MASK = 0xF
  CALL_STACK_MASK = 0xFFFFFFFF & 0x8
  NONVOLATILE_REGISTER_MASK = 0xFF0
  RESERVED_BITS = RESERVED_REGISTER_MASK
  MAX_REGISTERS = 256
  MAX_NONVOLATILE_REGISTERS = 32

  def arg_register_ary(argc)
    [*FIRST_ARGUMENT_REGISTER ... (FIRST_ARGUMENT_REGISTER+argc)]
  end

  def temp_name
    name = "#{@temp_name}"
    @temp_name += 1
    name
  end

  def write(*args)
    str = args.join
    @output.write @indent if @should_indent
    str = str.gsub("\n", "#{@indent}\n")
    @output.write str
    @should_indent = str.end_with? "\n"
    self
  end

  def puts(*args)
    str = args.join
    @output.write "\n" unless @should_indent
    @output.write @indent
    @output.puts str.gsub("\n", "#{@indent}\n")
    @should_indent = true
    self
  end

  def bit_array(*args)
    "[#{args.join ' '}]"
  end

  def arg_bits(argc, first_bit = FIRST_ARG_BIT)
    bits = 0
    case argc
    when Integer
      bits = (0...argc).reduce(0) { |bits, _| (bits << 1) | first_bit }
    when Array
      argc.each_with_index { |flag, bit|
        bits |= 1 << bit if flag
      }
    end
    bits
  end

  def emit(name, *args)
    write name
    unless args.empty?
      write " #{args.join ' '}"
    end
    write "\n"
    self
  end

  def initialize(output)
    @output = output
    @frame = [[RESERVED_BITS, 0]]
    @temp_name = 0
    @indent_level = 0
    @should_indent = true
    @indent = ''
  end

  def indent
    @indent_level += 1
    @indent = '        ' * @indent_level
  end

  def unindent
    raise "Cannot unindent at 0th column" if @indent_level <= 0
    @indent_level -= 1
    @indent = '        ' * @indent_level
  end

  def indented
    indent
    yield.tap { unindent }
  end


  def for_registers(count: nil, mask: nil, start: FIRST_ARGUMENT_REGISTER, volatile: true)
    raise ArgumentError, "No block given" unless block_given?
    registers = nil
    if !count.nil?
      registers = allocate_registers(count, start: start, volatile: volatile)
      mask = arg_bits(registers)
    elsif mask
      registers = []
      (0 ... 256).each { |i| registers << i if mask[i] > 0 }
    else
      raise ArgumentError, "Must specify one of count or mask"
    end

    push_frame()
    @frame.last[0] |= mask
    yield(*registers).tap { pop_frame }
  end

  def allocate_registers(count, start: nil, volatile: true)
    start ||= volatile ? FIRST_TEMPORARY_REGISTER : FIRST_ARGUMENT_REGISTER
    bit = start
    frame = @frame.last[0]
    max = volatile ? MAX_REGISTERS : MAX_NONVOLATILE_REGISTERS
    registers = []
    until registers.length == count || bit >= max
      if frame[bit] == 0
        registers << bit
        frame |= (1 << bit)
      end
      bit += 1
    end
    raise "All valid registers are reserved" unless registers.length == count
    @frame.last[0] = frame
    registers
  end

  def reserve_argc(argc)
    push_frame()
    @frame.last[0] |= arg_bits(argc)
    yield(*arg_register_ary(argc)).tap { pop_frame }
  end

  def begin_call(argc)
    push_frame(argc)
  end

  def for_call(argc, arg_registers)
    raise ArgumentError, "No block given" unless block_given?
    push_frame arg_registers
    yield
    emit 'pop', CALL_STACK_MASK
    emit 'load', 'rp', 0
  end

  def push_frame
    @frame << [*@frame.last]
    self
  end

  def pop_frame
    @frame.pop
  end

  SLUG_NAMES = {
    '?' => '_quest_',
    '!' => '_bang_',
    '$' => '_dollar_',
    '%' => '_percent_',
    '+' => '_plus_',
    '-' => '_dash_',
    '=' => '_equals_',
    '^' => '_caret_',
    '&' => '_amper_',
    '*' => '_star_',
    '@' => '_at_',
    '~' => '_tilde_',
    ',' => '_comma_',
    ':' => '_colon_',
    '<' => '_lt_',
    '>' => '_gt_',
    '.' => '_dot_',
    '/' => '_fslash_',
    "\\" => '_bslash_',
    "|" => '_pipe_'
  }

  def slug(name)
    name = name.dup
    SLUG_NAMES.each { |from, to| name.gsub!(from, to) }
    name
  end

  def export_label_name(name)
    "#{'.' unless name.to_s.start_with?('.')}#{name}"
  end

  def export_label(name)
    label = export_label_name(name)
    puts label
    label
  end

  def local_label_name(prefix = nil)
    "@_#{slug(prefix.to_s)}#{'_' if prefix}#{temp_name}__"
  end

  def local_label(prefix = nil)
    label = local_label_name(prefix)
    puts label
  end

  def comment(line)
    if line.include? "\n"
      line = line.gsub('*/', '*/ /*')
      puts "/*"
      indented {
        line.each_line { puts line.strip }
      }
      puts "*/"
    else
      puts "// #{line.strip}"
    end
  end

end

MATH_OPS = [
  :+, :-,
  :*, :/,
  :and, :or, :not,
  :'bitwise-and',
  :'bitwise-or',
  :'bitwise-xor',
  :'bitwise-shift',
  :'remainder',
  :'bitwise-not',
  :>,
  :>=,
  :<,
  :<=,
  :'eq',
  :'ne'
]

MATH_N_ARY_INSTRUCTIONS = {
  :+ => 'add',
  :- => 'sub',
  :/ => 'div',
  :remainder => 'mod',
  :* => 'mul',
  # bitwise-shift not included because it's a special case
  :'bitwise-and' => 'and',
  :'bitwise-or' => 'or',
  :'bitwise-xor' => 'xor',
  :and => 'logand',
  :or => 'logor',
  :'>' => 'gt',
  :'>=' => 'gte',
  :'<' => 'lt',
  :'<=' => 'lte',
  :'eq' => ''
}

UPPER = Object.new
BARRIER = Object.new
GLOBALS = Object.new

def UPPER.inspect
  :^.inspect
end

def BARRIER.inspect
  :block.inspect
end

def GLOBALS.inspect
  :*.inspect
end

Global = Struct.new(:address)
Function = Struct.new(:label, :funcdef)
Label = Struct.new(:name, :symbol)
Register = Struct.new(:index)

class Label
  def to_s
    self.name
  end
end

class Function
  def to_s
    self.label.to_s
  end
end

class Register
  def to_s
    self.index.to_s
  end
end

def global_names(names)
  names && (root_names(names)[GLOBALS] ||= {})
end

def root_names(names)
  names = names[UPPER] while names && names[UPPER]
  names
end

def lookup(name, names, skip_barrier = false)
  result = nil
  while result.nil? && names
    result = names[name]
    return result if !result.nil? || (names[BARRIER] && !skip_barrier) || names[UPPER].nil?
    names = names[UPPER]
  end
  result || global_names(names)[name]
end

def bytecode_call(expr, names, stack)
end

def bytecode_n_ary_op(reg, operator, operands, names, stack)
  fail_label = stack.local_label_name('failure')
  last_index = operands.length - 1

  operands.each_with_index { |op, index|
    instr = MATH_N_ARY_INSTRUCTIONS[operator]

    case operator
    when :and, :or
      jump_instr = op == :and ? 'jezl' : 'jnzl'
      bytecode(op, names, stack) { |sub, emitter|
        sub = emitter.call if emitter

        case sub
        when Register then
          stack.emit instr, reg, reg, sub
          stack.emit jump_instr, fail_label
          stack.emit 'mov', reg, sub if index == last_index

        when Label then # always true
          stack.emit 'load', reg, sub

        else
          raise "Can't accumulate logical and with #{op} -> #{sub}"
        end
      }

    else
      bytecode(op, names, stack) { |sub, emitter|
        stack.emit "f#{instr}#{'l' unless emitter.nil?}", reg, sub
      }

    end
  }

  if operator == :and || operator == :or
    succ_label = stack.local_label_name('success')
    stack.emit 'jmpl', succ_label
    stack.emit fail_label
    stack.emit 'load', reg, 0
    stack.emit succ_label
  end
end

def bytecode_binary_op(reg, operator, operands, names, stack)
end

def bytecode_unary_op(reg, operator, names, stack)
end

def bytecode_math(expr, names, stack)
  operator = expr[0]
  operands = expr.inner[1..-1]

  first_elem = bytecode(operands[0], names, stack)

  stack.for_registers(count: 1) { |out|
    stack.emit 'mov', out, first_elem if out != first_elem

    case
    when FoldMathOp::MATH_N_ARY_FUNCS.include?(operator)
      if operator == :- && operands.length == 1
        bytecode_unary_op(out, operator, names, stack)
      else
        bytecode_n_ary_op(out, operator, operands[1..-1], names, stack)
      end
    end

    Register[out]
  }
end

def descend_names(names, barrier = false)
  { UPPER => names, BARRIER => barrier }
end

def bytecode_func(expr, names, stack, named: nil, label: nil)
  label ||= stack.local_label("anonfunc")
  named ||= label
  names = descend_names(names, true)
  names[:'recurse->'] = Function[]

  stack.indent

  stack.reserve_argc(expr.arguments.length) { |*argv|
    argv.each_with_index { |reg, index|
      names[expr.arguments[index]] = Register[reg]
    }

    result_reg = nil
    expr.each { |se| result_reg = bytecode(se, names, stack) }
    result_reg ||= RETURN_REG
    stack.emit 'return', result_reg
  }

  stack.comment "end of function #{named}"
  stack.unindent

  Label[label]
end

def bytecode(expr, names = nil, stack = nil)
  stack ||= VMStack.new($stdout)
  names = descend_names(names)

  stack.comment(expr.to_s)

  case expr
  when FuncDef
    bytecode_func(expr, names, stack)

  when Numeric, String, true, false
    expr =
      case expr
      when Numeric then expr.to_f
      when true then 1.0
      when false then 0.0
      else expr
      end
    local_emit = emit = -> (&block) {
      stack.for_registers(count: 1) { |load|
        stack.emit 'load', load, expr.inspect
        expr = Register[load].tap { |k| block[k] if block }
      }
    }

    if block_given?
      yield(expr, local_emit)
    else
      local_emit.call
    end
    return expr

  when Symbol
    lookup(expr, names)

  when SExpr
    case
    when MATH_OPS.include?(expr[0])
      bytecode_math(expr, names, stack)

    when expr[0] == :define && expr[2].kind_of?(FuncDef)
      name = expr[1]
      label = stack.export_label(name)
      global_names(names)[name] = Function[label, expr]
      bytecode_func(expr[2], names, stack, label: label, named: name)
    end
  end.tap { |k|
    yield k if block_given?
  }
end

end # CL
