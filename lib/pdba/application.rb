# sublime: x_syntax Packages/Ruby/Ruby.tmLanguage
# sublime: translate_tabs_to_spaces true; tab_size 2

require 'optparse'
require 'pathname'
require 'etc'

require 'sinatra/base'
require 'sinatra/config_file'

require 'pdba/core_ext/logger'
require 'pdba/backend'

module PDBA
  class Application < Sinatra::Base
    register Sinatra::ConfigFile

    class << self
      def option_parser
        @option_parser ||= begin
          # hidden option: used by daemonize in jruby mode
          enable :spawned if ARGV.delete('--spawned') && RUBY_ENGINE == 'jruby'

          OptionParser.new do |op|
            op.separator ''
            op.separator 'Server Settings:'
            op.on('-s', '--rack-server SERVER',  'specify rack server/handler (default is thin)')                           { |val| set :server, val }
            op.on('-p', '--port PORT',           'set the port (default is 4567)')                                          { |val| set :port, Integer(val) }
            op.on('-o', '--addr ADDR',           "set the host (default is #{bind})")                                       { |val| set :bind, val }
            op.on('-e', '--env ENV',             'set the environment (default is development)')                            { |val| set :environment, val.to_sym }
            op.on('-x', '--mutex',               'turn on the mutex lock (default is off)')                                 {       set :lock, true }

            op.separator ''
            op.separator 'Daemon Settings:'
            op.on('-c', '--config FILE',   "Path to config file (default is #{config_path})")                               { |val| set :config_path, val }
            op.on('-d', '--daemonize',     "Run in background; implies --syslog (default is #{asdaemon ? 'on' : 'off'})")   { |val| enable :asdaemon, :syslog}
            op.on('-u', '--user USER',     "Drop privileges to this user (default is #{runasuser})")                        { |val| set :runasuser, val }
            op.on('-g', '--group USER',    "Drop privileges to this group (default is #{runasgroup})")                      { |val| set :runasgroup, val }

            op.separator ''
            op.separator 'Caching Options:'
            op.on('-C', '--cache-path PATH', "Path to store cache files in (default is #{cache_path})")                     { |val| set :cache_path, val }
            op.on('-T', '--cache-ttl TTL',   "Length of time to store cached data (default is #{cache_ttl})")               { |val| set :cache_ttl, val }

            op.separator ''
            op.separator 'Logging Options:'
            op.on('-P', '--pid-file FILE', "File to Store pid in when daemonized (default is #{pidfile})")                  { |val| set :pidfile, val }
            op.on('-l', '--log-file FILE', "File to log to (defaults to syslog logging)")                                   { |val| disable :syslog; set :logfile, val }
            op.on('-S', '--log-syslog',    "Use syslog instead of file log (default is yes when daemonized)")               { |val| enable :syslog; set :logfile, nil }

            op.separator ''
            op.separator 'General'
            op.on('-h', '--help', 'This help screen') { puts op.help ; exit(0) }
            op.on('-D', '--dump', 'Dump app env') { dump_env; exit(0) }
          end
        end
      end

      def initialize_backends
        Hash[backends].each do |name,uri|
          Backend::Manager.register(name, *uri.split(':'))
        end

        if Backend::Manager.count <= 0
          $stderr.puts "No viable backends found - quitting"
          exit! 1
        end
      end

      def initialize_logging
        return unless logfile || syslog

        if logfile
          fd = File.open(logfile.path, 'a'); fd.sync = true
          set :logger, LogFile.new(fd, 'weekly').tap { |l|
            l.level = Logger::DEBUG
            class << l; alias :write :<<; alias :puts :write; end
          }
          $stderr = STDERR.reopen("#{logfile.path}.console", 'a'); $stderr.sync = true
          $stdout = STDOUT.reopen("#{logfile.path}.console", 'a'); $stdout.sync = true
        elsif syslog
          set :logger, Logger::Syslog.new(PDBA::NAME).tap { |l|
            class << l; alias :write :<<; alias :puts :write; end
          }
          $stderr = ErrorLogger.new(logger)
          $stdout = InfoLogger.new(logger)
        end

        $stdin = STDIN.reopen('/dev/null', 'r') if asdaemon

        enable :logging
        use Rack::CommonLogger, logger
      end

      def initialize_cacher
        Backend::Cacher.path = cache_path
        Backend::Cacher.ttl  = cache_ttl
        Backend::Cacher.mkpath
      end

      def drop_privileges(user, group)
        # only root can change uid/gid
        if Process::Sys.getuid == 0
          Process::Sys.setuid(user)
          Process::Sys.setgid(group)
        end
      end

      def verify_runtime_credentials
        if [Process::Sys.getuid, Process::Sys.getgid, runasuser, runasgroup].any? { |v| v == 0 }
          puts "RUN AS USER: #{runasuser.inspect}"
          puts "RUN AS GROUP: #{runasgroup.inspect}"
          (bad_choices ||= []) << :user if runasuser == 0
          (bad_choices ||= []) << :group if runasgroup == 0
          puts "BAD CHOICES: #{bad_choices.inspect}"
          unless bad_choices.nil? || bad_choices.empty?
            $stderr.puts "Refusing to start with #{bad_choices.join('/')} set to root."
            exit(1)
          end
        end
      end

      def daemonize
        if pidfile.running?
          puts "#{PDBA::NAME} already running with pid #{pidfile.read} ..?"
          return
        end

        if RUBY_ENGINE == 'jruby'
          require 'spoon'
          unless spawned?
            if PDBA.jar?
              Dir.chdir PDBA::SCRIPT.dirname
              Spoon.spawnp(*(%W[ java -jar #{PDBA::SCRIPT.basename.to_s} --spawned ].concat(ARGV.dup)))
            else
              Spoon.spawnp(*(%W[ jruby -S #{PDBA::SCRIPT.to_s} --spawned ].concat(ARGV.dup)))
            end
            exit(0)
          end
        else
          Process.daemon(true, true)
          $0 = PDBA::NAME
        end

        pidfile.store
      end

      def run!(*args, &block)
         # parse options again to make sure command line overrides config file
        option_parser.parse!(ARGV.dup)
        @running = true
        begin
          verify_runtime_credentials
          initialize_backends
          return if asdaemon && !daemonize
          drop_privileges(runasuser, runasgroup)
          initialize_cacher
          initialize_logging
          super
        ensure
          begin
            pidfile.delete if pidfile.is_me?
          rescue Errno::EBADF
            # jruby can clean up the pidfile before we're done with it
            # so just log it and ignore if we get bad file descriptor.
            $stderr.puts "Got bad file descriptor (pidfile) on shutdown."
          end
        end
      end
    end

    configure do
      define_singleton(:logfile=, ->(value) {
        define_singleton(:logfile, proc { value ? LogFile.new(value) : nil })
      })

      define_singleton(:pidfile=, ->(value) {
        define_singleton(:pidfile, proc { value ? PidFile.new(value) : nil }) unless value.nil?
      })

      define_singleton(:config_file=, ->(value) {
        define_singleton(:config_file, proc { value ? Pathname.new(value) : nil }) unless value.nil?
      })

      define_singleton(:runasuser=, ->(value) {
        begin
          uid = (value ? Etc.getpwnam(value).try(:uid) : nil).tap { |uid|
            define_singleton(:runasuser, proc { uid }) if uid
          }
        rescue ArgumentError => e
          raise unless e.message.include? "can't find user"
          $stderr.puts "Can't drop privileges to non-existent user #{value}"
        end
      })

      define_singleton(:runasgroup=, ->(value) {
        begin
          (value ? Etc.getgrnam(value).try(:gid) : nil).tap { |gid|
            define_singleton(:runasgroup, proc { gid }) if gid
          }
        rescue ArgumentError => e
          raise unless e.message.include? "can't find group"
          $stderr.puts "Can't drop privileges to non-existent group #{value}"
        end
      })

      define_singleton(:cache_path=, ->(value) {
        define_singleton(:cache_path, proc { value ? Pathname.new(value) : nil }) unless value.nil?
      })

      define_singleton(:cache_ttl=, ->(value) {
        minimum_ttl = Backend::Cacher::MINIMUM_TTL
        unless (ttl = value.to_i) > minimum_ttl
          $stderr.puts "#{ttl} is less than the minimum cache ttl of #{minimum_ttl} - forcing to minimum."
          ttl = minimum_ttl
        end
        define_singleton(:cache_ttl, proc { ttl })
      })

      set :env,         :production
      set :host,        '127.0.0.1'
      set :port,        3000
      set :backends,    {}
      set :config_path, Pathname.new('/etc/').join(PDBA::NAME, "#{PDBA::NAME}.yml")
      set :pidfile,     File.join('/var/run', PDBA::NAME, "#{PDBA::NAME}.pid")
      set :logfile,     nil

      set :runasuser,   'nobody'
      set :runasgroup,  'nobody'

      set :cache_path,  Backend::Cacher::DEFAULT_PATH
      set :cache_ttl,   Backend::Cacher::DEFAULT_TTL

      disable :syslog, :asdaemon, :logging, :run, :spawned

      # this /must/ come after /all/ defaults, and setters are created
      option_parser.parse!(ARGV.dup)

      config_file(config_path.realpath)
    end

    before do
      env['rack.logger']       = logger
      env['rack.errors']       = logger
      response["Content-Type"] = "application/yaml"
    end


    # curl http://localhost/aggregate/?hostname=foo.bar.com
    get '/aggregate/' do
      Backend::Manager.aggregate(:facts_and_classes, params[:hostname]).to_yaml
    end

    # curl http://localhost/pdb01.example.com:8080/?hostname=foo.bar.com
    get '/:backend/' do
      Backend::Manager.single(params[:backend], :facts_and_classes, params[:hostname]).to_yaml
    end
  end
end