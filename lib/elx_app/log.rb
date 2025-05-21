# frozen_string_literal: true

require "logger"

require "elx_app"

module ElxApp
  ##
  # Any CLI Application should be able to log
  #
  module Log
    def with_logging(description, level: :info, log_return: false, log_error: true, &)
      validate_logger
      raise StandardError, "Log::with_logging: No block given" unless block_given?

      execute_with_logging(description, level: level, log_return: log_return, log_error: log_error, &)
    end

    private

    def validate_logger
      return if logger&.respond_to?(:add)

      raise StandardError, "Logger not initialized"
    end

    def execute_with_logging(description, level:, log_return:, log_error:)
      logger.send(level, ">>> Run '#{description}'")
      start_time   = Time.now
      return_value = yield
      elapsed      = Time.now - start_time
      logger.send(level, "<<< Return #{return_value} (#{elapsed.round(3)}s)") if log_return
      return_value
    rescue SystemCallError => e
      logger.error("!!! SysCallError '#{description}' - #{e}") if log_error
      raise
    rescue StandardError => e
      logger.error("!!! Failed '#{description}' - #{e}") if log_error
      raise
    end
  end
end

# Helper class to simplify console/unit tests around `log`
class QuickLog
  include ElxApp::Log
  attr_reader :logger

  def initialize(logger: nil, logfile: nil)
    @logger = logger || Logger.new(logfile || $stdout)
  end
end

# Helper class to simplify unit tests around `log`
class NilLog
  include ElxApp::Log
  attr_reader :logger
end
