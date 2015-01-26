# sublime: x_syntax Packages/Ruby/Ruby.tmLanguage
# sublime: translate_tabs_to_spaces true; tab_size 2

require 'pathname'

class Pathname
  def write(data, options={})
    mode     = options.delete(:mode) || 'w'
    flock    = options.delete(:flock)
    buffered = !options.delete(:unbuffered)

    self.open(mode) { |f|
      f.flock(flock) if flock
      buffered ? f.write(data) : f.syswrite(data)
      f.flock(File::LOCK_UN) if flock
    }
  end
end

class PidFile < Pathname
  def store!
    Process.pid.tap { |pid| write(pid, mode: 'w', unbuffered: true) }
  end

  def store
    return if running?
    $stderr.puts "overwriting stale pid #{self}" if stale?
    store!
  end

  def running?
    return false if (pid = read.to_i) <= 0
    !!Process.kill(0, pid)
  rescue Errno::ESRCH, Errno::ENOENT, Errno::ECHILD
    false
  end

  def stopped?
    !running?
  end

  def stale?
    exist? && stopped?
  end

  def is_me?
    exist? && running? && Process.pid == read.to_i
  end
end
