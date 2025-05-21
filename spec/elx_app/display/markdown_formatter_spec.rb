# frozen_string_literal: true

require "elx_app"

RSpec.describe ElxApp::Display::MarkdownFormatter do
  let(:display) { ElxApp::Display.new(level: :info) }

  describe "#markdown_format_title1" do
    it "formats a level-1 Markdown title" do
      expect(display.markdown_format_title1("Title")).to eq("# Title")
    end
  end

  describe "#markdown_format_list" do
    it "formats a Markdown list" do
      expect(display.markdown_format_list(%w[A B])).to eq("- A\n- B")
    end
  end

  describe "#markdown_format_table" do
    it "formats a Markdown table" do
      rows = [%w[A B], %w[C D]]
      expected = "Col1 | Col2\n--- | ---\nA | B\nC | D"
      expect(display.markdown_format_table(rows, headers: %w[Col1 Col2])).to eq(expected)
    end
  end

  describe "#markdown_format_note" do
    it "formats a Markdown note" do
      expect(display.markdown_format_note("Test note")).to eq("> **Note**: Test note")
    end
  end
end
