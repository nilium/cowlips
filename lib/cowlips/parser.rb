require 'cowlips/assertions'
require 'cowlips/lexer'
require 'cowlips/parser/sexpr'
require 'cowlips/parser/quote'

module CL

module Parser
  include Assertions

  # Given a stream of tokens, returns a quoted expressionf or that token stream.
  # The input token stream must start on a quote token.
  def quote(stream)
    tok = stop_error("Expected token input") { stream.next }
    expect("Expected quote token, got #{tok.kind}") { tok.kind == :quote }
    stop_error("Expecting quoted expression after quote at #{tok.pos}") {
      QuotedExpr.new(expr(stream)).tap { |k| k.inner.parent = k if k.inner.kind_of? Expr }
    }
  end

  # Given a stream of tokens, returns an expression for that token stream
  def expr(stream)
    case stream.peek.kind
    when :eof
      raise StopIteration
    when :invalid then raise stream.next.value
    when :quote then quote(stream)

    when :regex then raise "Unsupported type"
    when :name then stop_error("Expected name") {
      stream.next.value.to_sym
    }
    when :true, :false then stop_error("Expected boolean literal") {
      stream.next.to_bool
    }
    when :integer, :float, :hexnum, :binnum, :octnum
      stop_error("Expected number literal") { stream.next.to_num }

    when :paren_open
      start = stop_error("Expected opening parenthesis token") { stream.next }
      expect start.kind == :paren_open, "Expected opening parenthesis"
      stop_error("Unterminated s-expr starting at [#{start.line}:#{start.column}]") {
        ex = SExpr.new
        until stream.peek.kind == :paren_close
          ex.inner << expr(stream).tap { |k| k.parent = ex if Expr === k }
        end
        expect stream.next.kind == :paren_close, "Expected closing parenthesis"
        ex
      }

    when :nil
      stream.next
      QuotedExpr.new(SExpr.new([]))

    when :regexp, :string
      tok = stream.next
      eval(tok.value, nil, 'stream', tok.line)

    else
      raise RuntimeError, "Unhandled token: #{stream.peek.inspect}"

    end.tap { |i| pp i }
  end

  def parse(input)
    stream =
      case input
      when String then ::CL::lex(input)
      when IO     then ::CL::lex(input.read)
      when Lexer  then input.each
      when Enumerator
        case input.peek
        when String then ::CL::lex(input) # assumed char enumerator
        when Token  then input
        else raise ArgumentError, "invalid stream input"
        end
      end

    seq = []

    loop {
      break if stream.peek.kind == :eof
      seq << expr(stream)
      info "last parsed"
      pp seq.last
    }

    seq
  end

  alias_method :[], :parse

  extend self
end # Parser

end # CL
