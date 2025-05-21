# frozen_string_literal: true

require "tmpdir"
require "logger"

require "spec_helper"
require "elx_app/file_section_updater"

# Helper class for testing broadcast events
class Updater
  attr_reader :name, :logger, :prefix

  def initialize(name:, prefix:, logger:)
    @name = name
    @prefix = prefix
    @logger = logger
  end

  def before_update(event)
    @logger&.info("[#{name}] (enter) new_content: #{event[:new_content].join("\n")}")
    event[:new_content].unshift("#{prefix} [#{name}] before_update")
    @logger&.info("[#{name}] (exit) new_content: #{event[:new_content].join("\n")}")
  end

  def after_update(event)
    File.open(event[:file_path], "a") { |f| f.puts "#{prefix} [#{name}] Updated at #{Time.now}" }
  end
end

RSpec.describe ElxApp::FileSectionUpdater do
  let(:tmpdir) { Dir.mktmpdir }
  let(:file_path) { File.join(tmpdir, "test.txt") }
  let(:section) { "section" }
  let(:prefix) { "##" }
  let(:content) { %w[line1 line2] }
  let(:updater) do
    described_class.new(
      file_path: file_path,
      section: section,
      prefix: prefix,
      content: content
    )
  end
  let(:logger) { Logger.new("spec/support/log/fsu.log") }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#initialize" do
    it "raises ArgumentError for missing file path" do
      expect { described_class.new(file_path: nil, section: section) }
        .to raise_error(ArgumentError, /File path must be specified/)
    end

    it "raises ArgumentError for missing section" do
      expect { described_class.new(file_path: file_path, section: nil) }
        .to raise_error(ArgumentError, /Section must be specified/)
    end

    it "raises ArgumentError for missing prefix" do
      expect { described_class.new(file_path: file_path, section: section, prefix: nil) }
        .to raise_error(ArgumentError, /Prefix must be specified/)
    end

    it "raises ArgumentError for invalid content" do
      expect { described_class.new(file_path: file_path, section: section, content: [nil, Object.new]) }
        .to raise_error(ArgumentError, /Content must be an array of strings/)
    end

    it "converts content to strings" do
      updater = described_class.new(file_path: file_path, section: section, content: [123, "text"])
      expect(updater.content).to eq(%w[123 text])
    end

    context "when content contains markers" do
      let(:bad) { ["host: localhost", "## BEGIN section", "port: 3307"] }

      it "raises an error" do
        expect do
          described_class.new(file_path: file_path, section: section, prefix: prefix, content: bad)
        end.to raise_error(ArgumentError, "Content cannot contain markers (## BEGIN section or ## END section)")
      end
    end

    context "when content does not contain markers" do
      it "initializes without error" do
        expect do
          described_class.new(file_path: file_path, section: section, prefix: prefix, content: content)
        end.not_to raise_error
      end
    end
  end

  describe "#update" do
    context "when file does not exist" do
      it "creates file with markers and content" do
        updater.update
        expect(File.read(file_path)).to eq "## BEGIN section\nline1\nline2\n## END section\n"
      end
    end

    context "when file exists with markers" do
      before do
        File.write(file_path, <<~DEMO)
          header
          ## BEGIN section
          old content
          ## END section
          footer
        DEMO
      end

      it "replaces content between markers" do
        updater.update
        expect(File.read(file_path)).to eq "header\n## BEGIN section\nline1\nline2\n## END section\nfooter\n"
      end
    end

    context "when file exists without markers" do
      before do
        File.write(file_path, "header\ncontent\nfooter\n")
      end

      it "appends markers and content" do
        updater.update
        expect(File.read(file_path)).to eq "header\ncontent\nfooter\n## BEGIN section\nline1\nline2\n## END section\n"
      end
    end

    context "when markers are invalid" do
      before do
        File.write(file_path, "## END section\n## BEGIN section\n")
      end

      it "raises Error for invalid marker order" do
        expect { updater.update }.to raise_error(ElxApp::Error, /Invalid markers/)
      end
    end
  end

  describe "#update with multiple subscribers" do
    let(:updater1) do
      Updater.new(
        name: "Obj-1",
        prefix: prefix,
        logger: logger
      )
    end
    let(:updater2) do
      Updater.new(
        name: "Obj-2",
        prefix: prefix,
        logger: logger
      )
    end

    before do
      updater.subscribe(updater1)
      updater.subscribe(updater2)
    end

    context "when file exists with markers" do
      before do
        File.write(file_path, <<~TXT)
          header
          ## BEGIN section
          old content
          ## END section
          footer
        TXT
      end

      it "replaces content between markers with before_update modification" do
        updater.update
        expected = [
          "header",
          "## BEGIN section",
          "## [Obj-2] before_update",
          "## [Obj-1] before_update",
          "line1",
          "line2",
          "## END section",
          "footer",
          "## [Obj-1] Updated at"
        ].join("\n")
        expect(File.read(file_path)).to start_with(expected)
      end
    end

    context "when file exists without markers" do
      before do
        File.write(file_path, "header\ncontent\nfooter\n")
      end

      it "appends markers and content with before_update modification" do
        updater.update
        expected = [
          "header",
          "content",
          "footer",
          "## BEGIN section",
          "## [Obj-2] before_update",
          "## [Obj-1] before_update",
          "line1",
          "line2",
          "## END section",
          "## [Obj-1] Updated at"
        ].join("\n")
        expect(File.read(file_path)).to start_with(expected)
      end
    end
  end
end
