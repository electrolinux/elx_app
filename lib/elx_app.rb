# frozen_string_literal: true

require "rainbow"

require_relative "elx_app/version"

##
# Our main namespace
#
module ElxApp
  #
  # Default ElxAp::Error
  #
  class Error < StandardError; end

  # Config specific errors
  class ConfigFileNotFoundError < Error; end
  class LoaderFileNotFoundError < Error; end
  class LoaderKeyNotFoundError < Error; end
  class InvalidKeyError < Error; end

  # Raised when the application needs to exit with a specific status code.
  # rubocop:disable Lint/MissingSuper
  class ExitError < Error
    # @param status_code [Integer] The exit status code (default: 1)
    # @param message [String] Exit status message
    def initialize(status_code = 1, message = nil)
      Rainbow(message).red.bright if status_code && message
      exit status_code
    end
  end
  # rubocop:enable Lint/MissingSuper

  # Path-related errors
  class PathError < Error
    attr_reader :path

    def initialize(path, msg = nil)
      @path = path
      super(msg || default_message)
    end

    def default_message
      "Problem with path '#{path}'"
    end
  end

  # rubocop:disable Style/Documentation
  class FileNotFoundError < PathError
    def default_message
      "No files found for '#{path}'"
    end
  end

  class PathDoesNotExistError < PathError
    def default_message
      "Path '#{path}' does not exist"
    end
  end

  class PathNotReadableError < PathError
    def default_message
      "Path '#{path}' is not readable"
    end
  end

  class PathNotWritableError < PathError
    def default_message
      "Path '#{path}' is not writable"
    end
  end

  class CliError < Error
    attr_reader :output

    def initialize(message = nil, output = nil)
      super(message)
      @output = output
    end
  end
  # rubocop:enable Style/Documentation

  # Signals the application to exit with a specific status code.
  # @param status_code [Integer] The exit status code (default: 1)
  # @return [void]
  # @raise [ExitError] Unless in test or console mode
  def self.app_quit(status_code: 1, message: nil)
    return if skip_exit

    raise ExitError, status_code, message
  end

  # Checks if the application should skip exiting (e.g., in tests or console).
  # @return [Boolean]
  def self.skip_exit
    ENV["APP_ENV"] == "test" || File.basename($PROGRAM_NAME) == "console"
  end

  autoload :Application, "elx_app/application"
  autoload :Config, "elx_app/config"
  autoload :Display, "elx_app/display"
  autoload :FileSectionUpdater, "elx_app/file_section_updater"
  autoload :Generator, "elx_app/generator"
  autoload :Log, "elx_app/log"
  autoload :Options, "elx_app/options"
  autoload :PathUtils, "elx_app/path_utils"
  autoload :RootUtils, "elx_app/root_utils"
end
