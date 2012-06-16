module PuppetAcceptance
  class CLI
    def initialize
      @options = PuppetAcceptance::Options.parse_args
      @logger = PuppetAcceptance::Logger.new(@options)
      @options[:logger] = @logger
      @config = PuppetAcceptance::TestConfig.new(@options[:config], @options)

      if @options[:config] then
        @logger.debug "Using Config #{@options[:config]}"
      else
        fail "Argh!  There is no default for Config, specify one!"
      end

      @hosts =  []
      @config['HOSTS'].each_key do |name|
        @hosts << PuppetAcceptance::Host.create(name, @options, @config)
      end
    end

    def execute!
      begin
        trap(:INT) do
          @logger.warn "Interrupt received; exiting..."
          exit(1)
        end

        run_suite('pre-setup', pre_options, :fail_fast) if @options[:pre_script]
        run_suite('setup', setup_options, :fail_fast)
        run_suite('acceptance', @options) unless @options[:installonly]

      ensure
        @hosts.each {|host| host.close }
      end
    end

    def run_suite(name, options, failure_strategy = false)
      PuppetAcceptance::TestSuite.new(
        name, @hosts, options, @config, failure_strategy
      ).run_and_exit_on_failure
    end

    def setup_options
      setup_opts = nil
      if @options[:noinstall]
        setup_opts = @options.merge({
          :random => false,
          :tests  => ["setup/early", "setup/post"] })

      elsif @options[:upgrade]
        setup_opts = @options.merge({
          :random => false,
          :tests  => ["setup/early", "setup/pe_upgrade", "setup/post"] })

      elsif @options[:type] == 'cp_pe'
        setup_opts = @options.merge({
          :random => false,
          :tests => ["setup/early/01-vmrun.rb", "setup/cp_pe"] })

      elsif @options[:type] == 'pe_aws'
        setup_opts = @options.merge({
          :random => false,
          :tests => ["setup/pe_aws"] })

      elsif @options[:uninstall]
        setup_opts = @options.merge({
          :random => false,
          :tests  => ["setup/early", "setup/pe_uninstall/#{@options[:uninstall]}"] })

      else
        setup_opts = @options.merge({
          :random => false,
          :tests  => ["setup/early", "setup/#{@options[:type]}", "setup/post"] })
      end
      setup_opts
    end

    def pre_options
      @options.merge({
        :random => false,
        :tests => [ 'setup/early', @options[:pre_script] ] })
    end
  end
end
