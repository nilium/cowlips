module CL

module Logger
  module Settings
    COLORS = {
      red:      '[31;m',
      green:    '[32;m',
      yellow:   '[33;m',
      blue:     '[34;m',
      no_color: '[0;m'
    }

    attr_accessor :colors_disabled

    def method_missing(sym, *args)
      colors_disabled ? '' : COLORS[sym]
    end

    def each_line(args)
      args.each { |i| i.to_s.each_line { |k| yield k.chomp } }
    end

    extend self
  end

  def info(*args)
    Settings.each_line(args) { |line| $stderr.puts "#{Settings.blue  }[info]#{Settings.no_color}    #{line}" }
  end

  def warn(*args)
    Settings.each_line(args) { |line| $stderr.puts "#{Settings.yellow}[warning]#{Settings.no_color} #{line}" }
  end

  def succ(*args)
    Settings.each_line(args) { |line| $stderr.puts "#{Settings.green }[success]#{Settings.no_color} #{line}" }
  end

  def err(*args)
    Settings.each_line(args) { |line| $stderr.puts "#{Settings.red   }[error]#{Settings.no_color}   #{line}" }
  end
end

include Logger
extend Logger

end
