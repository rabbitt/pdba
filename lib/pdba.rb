#!/usr/bin/env ruby

# sublime: x_syntax Packages/Ruby/Ruby.tmLanguage
# sublime: translate_tabs_to_spaces true; tab_size 2

require 'pdba/core_ext'
require 'pdba/errors'

module PDBA
  autoload :Application, 'pdba/application'
  autoload :Backend,     'pdba/backend'

  class << self
    def root
      Pathname.new(__FILE__).realpath.dirname.parent
    end

    def libroot
      root.join('lib')
    end

    def lib
      libroot.join('pdba')
    end

    def script_path
      Pathname.new(
        case __FILE__[%r|([^!]+)|]
          when /\.jar$/ then $1
          # theoretically, the bottom of the call stack has the
          # main script that started everything
          else caller.collect { |p| p.split(':').first }.uniq.last
        end
      ).realpath
    end
    alias :jar_path :script_path

    def jar?
      script_path.to_s.end_with? '.jar'
    end
  end

  NAME    = self.to_s.downcase
  VERSION = root.join('VERSION').read.strip
  SCRIPT  = script_path
end