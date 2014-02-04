require 'cowlips/lexer/error'
require 'cowlips/lexer/token'
require 'cowlips/log'

module CL

class Lexer
  include ::Enumerable

  LINE_COMMENT      = ';'.freeze
  WHITESPACE        = " \r\n\t".freeze
  ESCAPE_CHARS      = "abfnrtv\\\"?0\n".freeze  # unused
  DIGITS            = '0123456789'.freeze
  HEX_SEPARATOR     = 'x'.freeze
  OCT_SEPARATOR     = 'o'.freeze
  BIN_SEPARATOR     = 'b'.freeze
  EXP_SEPARATOR     = 'eE'.freeze
  EXP_PLUSMINUS     = '+-'.freeze
  DOT               = '.'.freeze
  OPEN_BRACKETS     = '([{'.freeze
  CLOSE_BRACKETS    = ')]}'.freeze
  BRACKETS          = "#{OPEN_BRACKETS}#{CLOSE_BRACKETS}".freeze
  QUOTES            = "'".freeze
  LITERAL_MARKER    = '#'.freeze
  HEX_DIGITS        = "#{DIGITS}abcdefABCDEF".freeze
  OCT_DIGITS        = "01234567".freeze
  BIN_DIGITS        = "01".freeze
  NUMBER_BOUND      = "#{QUOTES}#{BRACKETS}#{WHITESPACE}#{LINE_COMMENT}".freeze
  STRING_SENTINEL   = '"'.freeze
  REGEXP_SENTINEL   = '/'.freeze
  LITERAL_BOUND     = NUMBER_BOUND

  INVALID_INPUT     =
    "Invalid lexer input -- expected enumerator, enumerable or string-like".freeze

  class << self
    def define_test(name, &block)
      raise ArgumentError, "No block provided" unless block_given?

      define_method(name) {
        mark

        result = instance_eval(&block)

        if result || @position == @mark.last
          unmark
        else
          rewind
        end

        result
      }
    end
  end

  def initialize(char_input)
    @input =
      case
      when char_input.kind_of?(Enumerator) then char_input
      when char_input.respond_to?(:each_char) then char_input.each_char
      when char_input.respond_to?(:each) then char_input.each
      else raise ArgumentError, INVALID_INPUT
      end

    @buffer           = ''
    @include_peeked   = -> (set) { set.include?(peek) }
    @line             = 1
    @column           = 1
    @position         = 0
    @token_pos        = [@line, @column, @position]
    @mark             = []
  end

  def each(&block)
    if block_given?
      while has_next?
        token = next_token
        break if token.nil?
        yield token
      end
      self
    else
      self.to_enum(:each)
    end
  end

  def flush
    temp = @buffer
    @buffer = ''
    temp
  end

  def emit(kind, text = nil)
    pos, line, col = *@token_pos
    buffer_text = flush
    text ||= buffer_text
    Token[kind, text, pos, line, col, -> { @mark = pos }]
  end

  def eof?
    !has_next?
  end

  def eof
    emit :eof
  end

  def bracket?
    accept(BRACKETS)
  end

  def bracket
    emit case last
         when '(' then :paren_open
         when '{' then :curl_open
         when '[' then :square_open
         when ')' then :paren_close
         when '}' then :curl_close
         when ']' then :square_close
         else :bracket
         end
  end

  def number?
    (accept(EXP_PLUSMINUS) && accept(DIGITS)) ||
    (@buffer.empty? && accept(DIGITS))
  end

  def number
    accept_run(DIGITS)
    kind = :integer

    if accept('.')
      expected "decimal number (.[0-9]+)" unless accept_run(DIGITS)
      kind = :float
    end

    if accept(EXP_SEPARATOR)
      accept(EXP_PLUSMINUS)
      expected "exponent ( /e[+-]?\\d+/i )" unless accept_run(DIGITS)
      kind = :float
    end

    unless at_bound?
      expected "end of number", but_got: "continued numberness"
    end

    emit kind
  end

  def quote?
    accept(QUOTES)
  end

  def quote
    case last
    when "'" then emit :quote
    else expected "a single quote", but_got: last.inspect
    end
  end

  define_test(:string?) { accept(STRING_SENTINEL) }
  def string
    sentinel = last

    while has_next? do
      accept_until('\\', sentinel)

      break if accept(sentinel)

      unexpected_eof expected: "escaped character" unless accept('\\') && !read.empty?
      unexpected_eof expected: "closing #{sentinel}" unless has_next?
    end

    case sentinel
    when '"' then emit :string
    when '/' then regexp
    else emit :charseq
    end
  end

  def regexp
    accept_run('imxo')
    emit :regexp
  end

  define_test(:name?) do
    accept_until(WHITESPACE, QUOTES, BRACKETS, STRING_SENTINEL) || !@buffer.empty?
  end

  def name
    emit :name
  end

  define_test(:regexp?) { accept(REGEXP_SENTINEL) }
  define_test(:hexnum?) { accept(HEX_SEPARATOR) }
  define_test(:octnum?) { accept(OCT_SEPARATOR) }
  define_test(:binnum?) { accept(BIN_SEPARATOR) }
  define_test(:literal?) { accept(LITERAL_MARKER) }
  define_test(:nil_seq?) { accept_seq('nil') }
  def literal
    case
    when regexp? then string
    when hexnum? then base_literal(:hexnum, HEX_DIGITS)
    when octnum? then base_literal(:octnum, OCT_DIGITS)
    when binnum? then base_literal(:binnum, BIN_DIGITS)
    when accept('t') then emit :true
    when accept('f') then emit :false
    when nil_seq? then emit :nil
    else expected 'one of nil, x, o, b, t, or f'
    end
  end

  def base_literal(kind, digits)
    expected "#{kind} literal" unless accept_run(digits)
    emit kind
  end

  define_test(:comment?) { skip(LINE_COMMENT) }
  def comment
    skip_until("\n")
    skip_run WHITESPACE
  end

  def unexpected_eof(expected: nil)
    if expected
      raise LexerError, "Unexpected end of text - expected #{expected}"
    else
      raise LexerError, "Unexpected end of text", *args
    end
  end

  def expected(expected, but_got: peek.inspect)
    if but_got
      raise LexerError, "Expected #{expected}, but got #{but_got}"
    else
      raise LexerError, "Expected #{expected}"
    end
  end

  def next_token
    skip_run WHITESPACE

    @token_pos = [@position, @line, @column]

    while comment?
      comment
      skip_run WHITESPACE
    end

    case
    when eof?
    when eof? then eof
    when quote? then quote
    when literal? then literal
    when string? then string
    when bracket? then bracket
    when number? then number
    when name? then name
    else raise LexerError, "Unexpected character: #{peek.inspect}"
    end
  # rescue LexerError => error
    # err "Buffer at error point in lexer: #{@buffer.inspect}"
    # err error.message
    # err error.backtrace.map { |b| "  #{b}" }.join($/)
    # emit :invalid, error.message
  end

  def read(buffered: true)
    char = @input.next
    @buffer << char if buffered

    if char == "\n"
      @line += 1
      @column = 0
    end

    @position += 1
    @column += 1

    char
  rescue StopIteration => done
    ''
  end

  def skip(*chars)
    if chars.length > 0
      if has_next? && chars.any?(&@include_peeked)
        skip
      else
        false
      end
    else
      begin
        read(buffered: false) != ''
      rescue StopIteration => done
        false
      end
    end
  end

  def peek
    @input.peek
  rescue StopIteration => done
    ''
  end

  def at_bound?
    !has_next? || check(LITERAL_BOUND)
  end

  def check(*chars, &block)
    block = @include_peeked unless block_given?
    has_next? && chars.any?(&block)
  end

  def last
    (!@buffer.empty? && @buffer[-1]) || ''
  end

  def accept(*chars)
    if has_next? && chars.any?(&@include_peeked)
      c = self.read
      yield c if block_given?
      true
    else
      false
    end
  end

  def accept_seq(*seq)
    seq = seq.flatten.join
    length = seq.length
    enum = seq.each_char
    loop { return false unless accept(enum.next) }
    true
  end

  def accept_while(buffered: true, &block)
    read_len = @position

    self.read(buffered: buffered) while has_next? && yield

    read_len = @position - read_len

    case
    when read_len > 0 then read_len
    when read_len < 0 then raise LexerError, "Underflow on read position"
    else nil
    end
  end

  def accept_run(*chars)
    accept_while { chars.any?(&@include_peeked) }
  end

  def accept_until(*chars)
    accept_while { !chars.any?(&@include_peeked) }
  end

  def skip_run(*chars)
    accept_while(buffered: false) { chars.any?(&@include_peeked) }
  end

  def skip_until(*chars)
    accept_while(buffered: false) { !chars.any?(&@include_peeked) }
  end

  def has_next?
    !peek.empty?
  end

  def rewind
    @input.rewind

    @line       = 1
    @column     = 0
    @position   = 0

    if @mark.length > 0
      (0 ... @mark.pop).each { skip }
    end
    self
  end

  def mark
    @mark.push @position
  end

  def unmark
    @mark.pop
  end

end

class << self
  def lex(input)
    Lexer.new(input).each
  end
end

end
