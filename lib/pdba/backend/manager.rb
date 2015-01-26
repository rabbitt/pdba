# sublime: x_syntax Packages/Ruby/Ruby.tmLanguage
# sublime: translate_tabs_to_spaces true; tab_size 2

require 'singleton'
require 'monitor'

module PDBA
  module Backend
    class Manager
      include Singleton

      class << self
        def method_missing(method, *args, &block)
          return super unless instance.respond_to? method
          instance.public_send(method, *args, &block)
        end
      end

      attr_accessor :overrides, :injections

      def initialize
        @overrides  = {}
        @injections = {}
        @backends   = {}
        @mutex      = Monitor.new
      end

      def register(name, host, port = Server::DEFAULT_PORT)
        host, port = [*host.split(':'), port]
        begin
          return @backends[name] unless @backends[name].nil?
          @mutex.synchronize {
            @backends[name] ||= Server.new(host, port)
          }
        rescue ConnectionError
          $stderr.puts "Unable to connect to server #{host}:#{port} - skipping..."
        end
      end

      def reset!
        @mutex.synchronize { @backends.clear }
      end


      def [](backend)
        @backends[backend]
      end

      def count
        @backends.size
      end
      alias :size :count

      def single(backend, method, *args)
        with_cache(cache_key(backend, method, *args)) do |cache|
          @backends[backend].send(method, *args).flatten.uniq
        end
      end

      def aggregate(method, *args)
        with_cache_key(cache_key(__method__, method, *args)) do
          @backends.values.inject([]) do |resources,backend|
            resources << backend.send(method, *args)
            resources
          end.flatten.uniq
        end
      end

      private

        def cache_key(*args)
          Digest::SHA1.hexdigest(args.join)
        end

        def cache
          Cacher.instance
        end
        private :cache

        def with_cache_key(key)
          cache[key] = yield cache
        end
        alias :with_cache :with_cache_key
    end
  end
end