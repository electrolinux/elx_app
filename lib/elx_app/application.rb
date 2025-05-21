# frozen_string_literal: true

require "logger"
require "optparse"
require "rainbow"
require "wisper"
require "elx_app/config"
require "elx_app/options"
require "elx_app/path_utils"

module ElxApp
  #
  # Base class for any CLI application
  #
  class Application
    include Wisper::Publisher
    include PathUtils

    attr_reader :options, :logger, :config
    attr_accessor :args

    # Creates an application instance with error handling
    # @param app [Class] Application class
    # @param options [ElxApp::Options, nil] Options instance
    # @param logger [Logger, nil] Logger instance
    # @param config [ElxApp::Config, nil] Config instance
    # @return [Application]
    def self.ensure_app(app, options: nil, logger: nil, config: nil)
      app.new(options: options, logger: logger, config: config)
    rescue Error => e
      puts Rainbow("Error: #{e.message}").red
      ElxApp.app_quit
    end

    # @param options [ElxApp::Options, nil] Options instance
    # @param logger [Logger, nil] Logger instance
    # @param config [ElxApp::Config, nil] Config instance
    def initialize(options: nil, logger: nil, config: nil)
      raise ArgumentError, "options must be an ElxApp::Options instance" unless options.nil? || options.is_a?(Options)

      @options = options || Options.new
      @logger  = logger
      @config  = config || Config.new
      @args    = []
    end

    # Parses command-line arguments and broadcasts parsed event
    # @param argv [Array<String>] Command-line arguments
    def parse(argv)
      opt_parser = OptionParser.new { |parser| parse_options(parser, argv) }
      logger&.debug("Broadcasting parsed event with args: #{@args.inspect}")
      broadcast(:parsed, self, options, @args)
      options
    rescue OptionParser::InvalidOption => e
      exit_parser(opt_parser, message: e.message, status_code: 1)
    rescue ElxApp::Error
      raise
    rescue StandardError => e
      exit_parser(opt_parser, message: e.message)
      options
    end

    # Runs the application (must be implemented by subclasses)
    # @raise [NotImplementedError] If not overridden
    def run
      raise NotImplementedError, "Subclasses must implement `run`"
    end

    # Quits the application with a status code
    # @param status_code [Integer] Exit status code
    # @raise [ExitError] Always raises to exit
    def self.app_quit(status_code: 0)
      ElxApp.app_quit(status_code: status_code)
    end

    private

    def parse_options(parser, argv)
      options.define_options(parser)
      parser.parse!(argv)
      @args = argv
      configure_logger if options.log
      initialize_config if options.config
    end

    # Initializes the configuration from options.config_file
    # @return [ElxApp::Config]
    def initialize_config
      return cached_config if config_already_loaded?

      load_and_log_config
    rescue StandardError => e
      log_and_raise_error(e)
    end

    # Configures the logger based on options
    def configure_logger
      ensure_writable_path(File.dirname(options.log_file)) if options.log_file
      @logger ||= Logger.new(options.log_file || $stderr)
      @logger.level = options.log_level
    end

    # Exits with a parser error message
    # @param parser [OptionParser] Option parser instance
    # @param message [String] Error message
    def exit_parser(parser, message: nil, status_code: 0)
      puts Rainbow(message).red.bright if message
      @logger&.warn("Application quit during `parse`: #{message}") if message
      puts parser
      ElxApp.app_quit(status_code: status_code, message: message)
    end

    def cached_config
      @config
    end

    def config_already_loaded?
      !options.config || !options.config_file
    end

    def load_and_log_config
      ensure_readable_path(File.dirname(options.config_file))
      @config = Config.from_file(options.config_file)
      @logger&.debug("Loaded configuration: #{@config.to_h.inspect}")
      @config
    end

    def log_and_raise_error(error)
      @logger&.error("Failed to load configuration: #{error.message}")
      raise Error, "Failed to load configuration: #{error.message}"
    end
  end
end
