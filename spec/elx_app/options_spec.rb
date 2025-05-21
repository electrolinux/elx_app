# frozen_string_literal: true

require "optparse"

require "spec_helper"

RSpec.describe ElxApp::Options do
  let(:options) { described_class.new(app: "test", version: "0.3.4") }

  describe "#define_options" do
    it "sets up help option" do
      parser = OptionParser.new
      options.define_options(parser)
      expect { parser.parse!(["--help"]) }.to output(/Usage: test/).to_stdout
    end

    it "sets up version option" do
      parser = OptionParser.new
      options.define_options(parser)
      expect { parser.parse!(["--version"]) }.to output(/0.3.4/).to_stdout
    end

    it "sets up verbose option" do
      parser = OptionParser.new
      options.define_options(parser)
      parser.parse!(["--verbose"])
      expect(options.output_level).to be "verbose"
    end

    it "sets up quiet option" do
      parser = OptionParser.new
      options.define_options(parser)
      parser.parse!(["--quiet"])
      expect(options.output_level).to be "quiet"
    end

    it "sets up log file option" do
      parser = OptionParser.new
      options.define_options(parser)
      parser.parse!(["--log-file", "output.log"])
      expect(options.log_file).to eq "output.log"
    end

    it "sets up config option" do
      parser = OptionParser.new
      options.define_options(parser)
      parser.parse!(["--config"])
      expect(options.config).to be true
      expect(options.config_file).to include("test.yml")
    end

    it "sets up config-file option" do
      parser = OptionParser.new
      options.define_options(parser)
      parser.parse!(["--config-file", "custom.yml"])
      expect(options.config_file).to eq "custom.yml"
      expect(options.config).to be true
    end

    it "raise if both verbose and quiet options are given" do
      parser = OptionParser.new
      options.define_options(parser)
      expect do
        parser.parse!(["-v", "-q"])
      end.to raise_error(OptionParser::InvalidOption, /Cannot combine --verbose and --quiet/)
    end

    it "raise if log_file is invalid" do
      parser = OptionParser.new
      options.define_options(parser)
      expect do
        parser.parse!(["--log-file", "/root/not-allowed.log"])
      end.to raise_error(OptionParser::InvalidOption, /Invalid log_file/)
    end

    it "raise if config_file is invalid" do
      parser = OptionParser.new
      options.define_options(parser)
      expect do
        parser.parse!(["--config-file", "/root/not-allowed.yml"])
      end.to raise_error(OptionParser::InvalidOption, /Invalid config_file/)
    end

    it "raises for unwritable config file directory" do
      parser = OptionParser.new
      options.define_options(parser)
      expect do
        parser.parse!(["--config-file", "/root/inaccessible.yml"])
      end.to raise_error(OptionParser::InvalidOption, /Invalid config_file.*not readable or directory is not writable/)
    end
  end
end
