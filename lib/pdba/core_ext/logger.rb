# sublime: x_syntax Packages/Ruby/Ruby.tmLanguage
# sublime: translate_tabs_to_spaces true; tab_size 2

require 'logger'
require 'syslog-logger'

class ErrorLogger < IO
  def initialize(logger)
    @logger = logger
  end
  def write(message)
    @logger.error(message)
  end
end

class InfoLogger < ErrorLogger
  def write(message)
    @logger.info(message)
  end
end

class LogFile < Logger
  attr_reader :path
  def initialize(path, *args)
    @path = path
    super(File.open(@path, 'a').tap {|fd| fd.sync = true}, *args)
  end

  def coerce(o)
    case o
      when String then [ @path, o ]
      else [ self, o ]
    end
  end
end
