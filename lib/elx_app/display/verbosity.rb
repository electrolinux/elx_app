# frozen_string_literal: true

require "elx_app/display"

module ElxApp
  class Display
    # Verbosity helper (modeled upon Logger::Severity)
    module Verbosity
      DEBUG    = 0
      VERBOSE  = 1
      INFO     = 2
      QUIET    = 3
      CRITICAL = 4

      LEVELS = {
        "debug" => DEBUG,
        "verbose" => VERBOSE,
        "info" => INFO,
        "success" => INFO,
        "quiet" => QUIET,
        "critical" => CRITICAL,
        "error" => CRITICAL
      }.freeze
      private_constant :LEVELS

      def coerce(level)
        if level.is_a?(Integer)
          level
        else
          key = level.to_s.downcase
          LEVELS[key] || raise(ArgumentError, "Invalid verbosity level: #{level}")
        end
      end
    end
  end
end
