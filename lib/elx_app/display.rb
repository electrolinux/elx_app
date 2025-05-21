# frozen_string_literal: true

require "rainbow"
require "elx_app"

require "elx_app/display/verbosity"
require "elx_app/display/text_formatter"
require "elx_app/display/markdown_formatter"

module ElxApp
  class Display
    include Verbosity
    include TextFormatter
    include MarkdownFormatter

    attr_reader :level, :rbw

    COLORS = %w[cyan yellow green ivory red].freeze

    def initialize(level: INFO)
      @level = coerce(level)
      @rbw = Rainbow.new
      @report = []
    end

    def level=(verbosity)
      @level = coerce(verbosity)
    end

    def output(verbosity, message = nil, color: false, report: false)
      return if verbosity < @level

      message = yield if message.nil? && block_given?
      display_message(verbosity, message, color: color)
      @report << message if report
      message
    end

    def display_message(verbosity, message, color: false)
      return puts message unless color
      return puts message if message.match?(/^\e\[[\d;]*[a-zA-Z]/)

      color = color == true ? COLORS[verbosity] : try_color(color, verbosity)
      puts rbw.wrap(message).send(color)
    end

    # Title methods (inspired by WhsTools::Display headers)
    def title1(message = nil, color: false, format: :text, report: false, &)
      formatted = format == :text ? text_format_title1(message) : markdown_format_title1(message)
      output(INFO, formatted, color: color, report: report, &)
    end

    def title2(message = nil, color: false, format: :text, report: false, &)
      formatted = format == :text ? text_format_title2(message) : markdown_format_title2(message)
      output(INFO, formatted, color: color, report: report, &)
    end

    def title3(message = nil, color: false, format: :text, report: false, &)
      formatted = format == :text ? text_format_title3(message) : markdown_format_title3(message)
      output(INFO, formatted, color: color, report: report, &)
    end

    # List method
    def list(items, color: false, format: :text, report: false)
      formatted = format == :text ? text_format_list(items) : markdown_format_list(items)
      output(INFO, formatted, color: color, report: report)
    end

    # Table method
    def table(rows, headers: [], color: false, format: :text, report: false)
      formatted = if format == :text
                    text_format_table(rows,
                                      headers: headers)
                  else
                    markdown_format_table(rows, headers: headers)
                  end
      output(INFO, formatted, color: color, report: report)
    end

    # Note method
    def note(message = nil, color: false, format: :text, report: false, &)
      formatted = format == :text ? text_format_note(message) : markdown_format_note(message)
      output(VERBOSE, formatted, color: color, report: report, &)
    end

    # Standard verbosity methods
    def critical(message = nil, color: false, report: false, &)
      output(CRITICAL, message, color: color, report: report, &)
    end

    alias error critical

    def quiet(message = nil, color: false, report: false, &)
      output(QUIET, message, color: color, report: report, &)
    end

    def info(message = nil, color: false, report: false, &)
      output(INFO, message, color: color, report: report, &)
    end

    alias success info

    def verbose(message = nil, color: false, report: false, &)
      output(VERBOSE, message, color: color, report: report, &)
    end

    def debug(message = nil, color: false, report: false, &)
      output(DEBUG, message, color: color, report: report, &)
    end

    # Accessor for report
    def report
      @report.dup
    end

    def clear_report
      @report.clear
    end

    def try_color(color, verbosity)
      rbw.wrap("Testing").send(color)
      color
    rescue NoMethodError
      COLORS[verbosity]
    end
  end
end
