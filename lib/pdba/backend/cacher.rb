# sublime: x_syntax Packages/Ruby/Ruby.tmLanguage
# sublime: translate_tabs_to_spaces true; tab_size 2

require 'singleton'
require 'pathname'
require 'monitor'

module PDBA
  module Backend

    class Cacher
      include Singleton

      DEFAULT_PATH = '/var/tmp/pdba/cache'
      DEFAULT_TTL  = 300
      MINIMUM_TTL  = 150

      attr_reader :path, :ttl

      class << self
        def method_missing(method, *args, &block)
          return super unless instance.respond_to? method
          instance.public_send(method, *args, &block)
        end
      end

      def initialize
        @mutex = Monitor.new
        @path  = Pathname.new(DEFAULT_PATH)
      end

      def ttl=(value)
        @ttl = Integer(value)
      end

      def path=(value)
        @path = Pathname.new(value)
      end

      def cache_file(key)
        @path.join(key)
      end

      def mkpath
        @path.mkpath unless @path.exist?
      end

      def store(key, value, force=false)
        return unless force || expired?(key)
        @mutex.synchronize do
          cache_file(key).write(Marshal.dump(value))
        end
      end
      alias :[]= :store

      def retrieve(key)
        return if expired? key
        @mutex.synchronize do
          Marshal.load(cache_file(key).read)
        end
      end
      alias :[] :retrieve

      def expired?(key)
        return true unless cache_file(key).exist?
        (cache_file(key).stat.mtime + @ttl) <= Time.now
      end
    end
  end
end