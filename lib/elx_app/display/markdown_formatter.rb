# frozen_string_literal: true

require "elx_app/display"

module ElxApp
  class Display
    # Helper module for Markdown formatting
    module MarkdownFormatter
      def markdown_format_title1(message)
        "# #{message}"
      end

      def markdown_format_title2(message)
        "## #{message}"
      end

      def markdown_format_title3(message)
        "### #{message}"
      end

      def markdown_format_list(items)
        items.map { |item| "- #{item}" }.join("\n")
      end

      def markdown_format_table(rows, headers: [])
        return "" if rows.empty?

        header_row = headers.join(" | ")
        separator = headers.map { "---" }.join(" | ")
        body = rows.map { |row| row.join(" | ") }
        [header_row, separator, *body].join("\n")
      end

      def markdown_format_note(message)
        "> **Note**: #{message}"
      end
    end
  end
end
