module CL
  INDENT_WHITESPACE_REGEX = /^\s*/
end

# String extension to get unindented heredoc strings.
# Only useful for writing heredocs/strings, so it won't be widely used
# and using a regexp here should be fine.
class String
  def min_column
    each_line.map do |line|
      line[CL::INDENT_WHITESPACE_REGEX].length if line != $/
    end.delete_if(&:nil?).min
  end

  def unindented(column = nil)
    column ||= min_column
    each_line.map { |l| l[column..-1] }.join
  end

  def unindent!(column = nil)
    column ||= min_column
    gsub!(/(?<=\n|^)#{' ' * column}/, '') if column > 0
    self
  end
end
