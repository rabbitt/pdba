# sublime: x_syntax Packages/Ruby/Ruby.tmLanguage
# sublime: translate_tabs_to_spaces true; tab_size 2

require 'open-uri'
require 'uri'
require 'json'
require 'yaml'
require 'socket'
require 'timeout'
require 'resolv'

module PDBA
  module Backend
    class Server
      DEFAULT_PORT = 8080

      def initialize(host, port = DEFAULT_PORT)
        scheme = [443, 8081].include?(port.to_i) ? 'https' : 'http'
        @uri   = URI("#{scheme}://#{host}:#{port}")
        raise ConnectionError, "Can't connect to #{@uri.to_s}" unless can_connect?
      end

      def url(path, query=nil)
        URI.join(@uri, path).tap { |uri|
          uri.query = prepare_query(query) unless query.nil?
        }
      end

      def can_connect?
        Timeout::timeout(1) {
          !TCPSocket.new(Resolv.getaddress(@uri.host), @uri.port).close
        }
      rescue Timeout::Error
        $stderr.puts "Timeout attempting to connect to #{@uri.host}:#{@uri.port}"
      rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH
        $stderr.puts "Unable to connect to #{@uri.host}:#{@uri.port}"
        false
      rescue Resolv::ResolvError
        $stderr.puts "Unable to resolve ip address for #{@uri.host}"
        false
      end

      def prepare_query(query)
        case query
          when Hash then
            query.collect { |k,v| "#{k}=#{URI.escape(v.to_s)}" }.join('&')
          when Array then
            "query=#{URI.escape(query.to_s)}"
          else
            query
        end
      end

      def resources(query = [])
        JSON.parse(open(url('/v3/resources', query), { 'Accept' => 'application/json'}).read)
      end

      def classes(host = nil)
        query = %w| = type Class |
        query = [ 'and', query, %W| = certname #{host} | ] if host

        Hash[
          resources(query).inject({}) do |hash,data|
            ((hash[data['certname']] ||= {})['classes'] ||= Set.new) << data['title']
            hash
          end.sort.each { |k,d| d['classes'] = d['classes'].to_a.join(',') }
        ]
      end

      def facts(host = nil)
        query = host ? %W| = certname #{host} | : nil
        facts = JSON.parse(open(url('/v3/facts', query), { 'Accept' => 'application/json'}).read)
        facts.inject({}) do |hash,data|
          data['value'] = "Serial Number #{data['value']}" if data['name'] == 'serialnumber'
          (hash[data['certname']] ||= {})[data['name']] = data['value']
          hash
        end
      end

      def facts_and_classes(host = nil)
        facts(host).deep_merge(classes(host))
      end
    end
  end
end