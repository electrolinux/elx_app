# frozen_string_literal: true

require "logger"
require "optparse"
require "rainbow"

require "elx_app"
require "elx_app/path_utils"

module ElxApp
  ##
  # Base class for any CLI Application to manage OptParser
  #
  class Options
    include PathUtils

    attr_reader :app, :version, :usage, :banner, :output_level,
                :log, :log_file, :log_level, :default_log,
                :config, :config_file, :default_config

    def initialize(app: nil, version: nil, usage: nil, banner: nil)
      @app            = app || File.basename($PROGRAM_NAME, File.extname($PROGRAM_NAME))
      @version        = version || ElxApp::VERSION
      @usage          = usage || default_usage
      @banner         = banner || default_banner
      @output_level   = "info"
      @log            = false
      @log_file       = nil
      @log_level      = "INFO"
      @default_log    = File.join(log_path(@app), "#{@app}.log")
      @config         = false
      @config_file    = nil
      @default_config = File.join(config_path(@app), "#{@app}.yml")
    end

    def default_usage
      "Usage: #{@app} [options] [<arg>...]"
    end

    def default_banner
      helpline, usage = @usage.split("\n", 2)
      [
        Rainbow("#{@app} v.#{@version} - #{helpline}").yellow,
        usage&.chomp,
        respond_to?(:define_app_options) ? "\nOptions:" : nil
      ].compact.join("\n")
    end

    def define_options(parser)
      parser.banner = @banner
      define_app_options(parser) if respond_to?(:define_app_options)
      parser.separator "\nCommon options:"
      define_generic_options(parser)
    end

    def define_generic_options(parser)
      define_help_and_version(parser)
      define_output_level(parser)
      define_log_options(parser)
      define_config_options(parser)
    end

    def define_help_and_version(parser)
      parser.on_tail("-h", "--help", "Show this help message") do
        puts parser
        help_footer if respond_to?(:help_footer)
        ElxApp.app_quit(status_code: 0)
      end

      parser.on_tail("-V", "--version", "Show version") do
        puts @version
        ElxApp.app_quit(status_code: 0)
      end
    end

    def define_output_level(parser)
      verbose_or_quiet = "Cannot combine --verbose and --quiet"

      parser.on_tail("-v", "--verbose", "Show more messages") do
        raise OptionParser::InvalidOption, verbose_or_quiet if @output_level == "quiet"

        @output_level = "verbose"
      end

      parser.on_tail("-q", "--quiet", "Suppress most output") do
        raise OptionParser::InvalidOption, verbose_or_quiet if @output_level == "verbose"

        @output_level = "quiet"
      end
    end

    def define_log_options(parser)
      log_default = Rainbow("Default [#{default_log}]").yellow

      parser.on_tail("--log", "Write logs to specified (or default) log-file.") do
        @log_file ||= @default_log
        @log = true
      end

      parser.on_tail("--log-file FILE", "Write logs to FILE. #{log_default}") do |file|
        @log_file = validate_log_file(file)
        @log = true
      end

      define_log_level_option(parser)
    end

    def define_log_level_option(parser)
      parser.on_tail("--log-level LEVEL", "Log level (DEBUG, INFO, WARN, ERROR, FATAL)") do |level|
        valid_levels = %w[DEBUG INFO WARN ERROR FATAL]
        unless valid_levels.include?(level.upcase)
          raise OptionParser::InvalidOption, "Invalid log level: #{level}. Must be one of #{valid_levels.join(", ")}"
        end

        @log_level = Logger.const_get(level.upcase)
        @log = true
      end
    end

    def define_config_options(parser)
      config_default = Rainbow("Default [#{default_config}]").yellow

      parser.on_tail("-c", "--config", "Load configuration from default config file. #{config_default}") do
        @config_file ||= @default_config
        @config = true
      end

      parser.on_tail("--config-file FILE", "Load configuration from FILE. #{config_default}") do |file|
        @config_file = validate_config_file(file)
        @config = true
      end
    end

    def validate_log_file(file)
      return file if File.writable?(file)

      unless path_writable?(File.dirname(file))
        raise OptionParser::InvalidOption, "Invalid log_file: #{file}. File or dir is not writable"
      end

      file
    end

    def validate_config_file(file)
      return file if File.readable?(file) || path_writable?(File.dirname(file))

      raise OptionParser::InvalidOption,
            "Invalid config_file: #{file}. File is not readable or directory is not writable"
    end
  end
end
