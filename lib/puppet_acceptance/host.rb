module PuppetAcceptance
  class Host

    def self.create(name, options, config)
      case config['HOSTS'][name]['platform']
      when /windows/
        Windows::Host.new(name, options, config)
      else
        Unix::Host.new(name, options, config)
      end
    end

    attr_accessor :logger
    def initialize(name, options, config)
      @logger = options[:logger]
      @name, @options, = name, options.dup
      @defaults = merge_defaults_for_type(config, options[:type])
    end

    def merge_defaults_for_type(config, type)
      defaults = type =~ /pe/ ? self.class.pe_defaults : self.class.foss_defaults
      config['CONFIG'].merge(defaults).merge(config['HOSTS'][name])
    end

    def []=(k,v)
      @defaults[k] = v
    end

    def [](k)
      @defaults[k]
    end

    def to_str
      @name
    end

    def to_s
      @name
    end

    def +(other)
      @name + other
    end

    attr_reader :name, :overrides

    # Wrap up the SSH connection process; this will cache the connection and
    # allow us to reuse it for each operation without needing to reauth every
    # single time.
    def ssh_connection
      @ssh_connection ||= SshConnection.connect(self, self['user'], self['ssh'])
    end

    def close
      @ssh_connection.close if @ssh_connection
    end

    def exec(command, options={})
      cmdline = command.cmd_line(self)

      @logger.debug "\n#{self} $ #{cmdline}"

      ssh_options = {
        :stdin => options[:stdin],
        :pty => options[:pty],
        :dry_run => $dry_run,
      }

      output_callback = logger.method(:host_output)

      result = ssh_connection.execute(cmdline, ssh_options, output_callback)

      unless options[:silent]
        result.log(@logger)
        unless result.exit_code_in?(options[:acceptable_exit_codes] || [0])
          limit = 10
          raise "Host '#{self}' exited with #{result.exit_code} running:\n #{cmdline}\nLast #{limit} lines of output were:\n#{result.formatted_output(limit)}"
        end
      end
      result
    end

    def do_scp(source, target)
      @logger.debug "localhost $ scp #{source} #{self}:#{target}"

      ssh_options = {
        :dry_run => $dry_run,
      }

      ssh_connection.scp(source, target, ssh_options)
    end
  end

  require File.expand_path(File.join(File.dirname(__FILE__), 'host/windows'))
  require File.expand_path(File.join(File.dirname(__FILE__), 'host/unix'))
end
