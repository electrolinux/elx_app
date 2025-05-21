# frozen_string_literal: true

require "elx_app"

RSpec.describe ElxApp::Display::TextFormatter do
  let(:display) { ElxApp::Display.new(level: :info) }

  describe "#text_format_title1" do
    it "formats a level-1 title with lines" do
      expect(display.text_format_title1("Title")).to match(/\A-+\nTitle\n-+\z/)
    end
  end

  describe "#text_format_list" do
    it "formats a list with bullets" do
      expect(display.text_format_list(%w[A B])).to eq("- A\n- B")
    end
  end

  describe "#text_format_table" do
    it "formats a table with headers" do
      rows = [%w[A B], %w[C D]]
      expected = "Col1 | Col2\n-----|-----\nA    | B\nC    | D"
      expect(display.text_format_table(rows, headers: %w[Col1 Col2])).to eq(expected)
    end
  end

  describe "#text_format_note" do
    it "formats a note with prefix" do
      expect(display.text_format_note("Test note")).to eq("Note: Test note")
    end
  end
end
