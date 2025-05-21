# frozen_string_literal: true

module ElxApp
  class Display
    # Helper module for plain text formatting
    module TextFormatter
      LINE_LENGTH = 79
      LINE_CHAR = "-"

      def text_format_title1(message)
        line = make_line
        [line, message, line].join("\n")
      end

      def text_format_title2(message)
        line = make_line
        [message, line].join("\n")
      end

      def text_format_title3(message)
        "#{message}:"
      end

      def text_format_list(items)
        items.map { |item| "- #{item}" }.join("\n")
      end

      def text_format_table(rows, headers: [])
        return "" if rows.empty?

        widths     = table_header_widths(rows, headers)
        header_row = table_header_row(widths, headers)
        separator  = widths.map { |w| "-" * w }.join("-|-")
        body       = table_body(rows, widths)
        [header_row, separator, *body].join("\n")
      end

      def text_format_note(message)
        "Note: #{message}"
      end

      private

      def make_line(len = LINE_LENGTH, char = LINE_CHAR)
        "".ljust(len, char)
      end

      def table_header_widths(rows, headers)
        headers.map.with_index do |_, i|
          [headers[i].to_s.length, *rows.map { |r| r[i].to_s.length }].max
        end
      end

      def table_header_row(widths, headers)
        headers.each_with_index.map { |h, i| h.to_s.ljust(widths[i]) }.join(" | ")
      end

      def table_body(rows, widths)
        rows.map do |row|
          row.each_with_index.map { |cell, i| cell.to_s.ljust(widths[i]) }.join(" | ").rstrip
        end
      end
    end
  end
end
