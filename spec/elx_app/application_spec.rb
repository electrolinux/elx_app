# frozen_string_literal: true

require "tmpdir"
require "fileutils"

require "spec_helper"
require "elx_app/application"
require "elx_app/options"
require "stringio"

# Tests for ElxApp::Application
#
RSpec.describe ElxApp::Application do
  let(:tmpdir) { Dir.mktmpdir }
  let(:options) { ElxApp::Options.new(app: "test_app", usage: "Test app", version: "1.0.0") }
  let(:app) { described_class.new(options: options) }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#initialize" do
    it "raises ArgumentError for invalid options" do
      expect { described_class.new(options: "invalid") }
        .to raise_error(ArgumentError, /options must be an ElxApp::Options instance/)
    end

    it "initializes with default config and args" do
      expect(app.config).to be_a(ElxApp::Config)
      expect(app.args).to eq([])
    end
  end

  describe "#parse" do
    it "parses arguments and stores them in args" do
      app.parse(["--verbose", "arg1", "arg2"])
      expect(app.args).to eq(%w[arg1 arg2])
    end

    it "broadcasts parsed event with block subscriber" do
      called = false
      app.on(:parsed) do |*args|
        _, _, args = args
        called = args
      end
      app.parse(["arg1"])
      expect(called).to eq(["arg1"])
    end

    it "broadcasts parsed event with method subscriber" do
      custom_app = Class.new(described_class) do
        def parsed(*args)
          _, _, args = args
          @called = args
        end
      end.new(options: options)

      custom_app.subscribe(custom_app)
      custom_app.parse(["arg1"])
      expect(custom_app.instance_variable_get(:@called)).to eq(["arg1"])
    end

    # TODO: fix
    it "calls multiple parsed subscribers" do
      custom_app = Class.new(described_class) do
        def parsed(*args)
          _, _, args = args
          @custom_called = args
        end
      end.new(options: options)

      custom_app.subscribe(custom_app)
      custom_app.on(:parsed) do |*args|
        _, _, args = args
        custom_app.instance_variable_set(:@block_called, args)
      end
      custom_app.parse(["arg1"])
      expect(custom_app.instance_variable_get(:@custom_called)).to eq(["arg1"])
      expect(custom_app.instance_variable_get(:@block_called)).to eq(["arg1"])
    end

    it "configures logger if log is enabled" do
      options = ElxApp::Options.new(app: "test_app", usage: "Test app", version: "1.0.0")
      options.instance_variable_set(:@log, true)
      options.instance_variable_set(:@log_file, File.join(tmpdir, "test.log"))
      options.instance_variable_set(:@log_level, Logger::INFO)
      app = described_class.new(options: options)

      app.parse([])
      expect(app.logger).to be_a(Logger)
      expect(File.exist?(File.join(tmpdir, "test.log"))).to be true
    end

    it "exit with error message for invalid config file" do
      options = ElxApp::Options.new(app: "test_app", usage: "Test app", version: "1.0.0")
      app = described_class.new(options: options)

      argv = %w[--config-file /invalid.yml]
      expect { app.parse(argv) }.to output(/Invalid config_file:/).to_stdout
    end

    it "exits cleanly with help message for -h" do
      expect { app.parse(["-h"]) }.to output(/Test app/).to_stdout
    end

    it "exits cleanly with help message for -h with parsed subscribers" do
      custom_app = Class.new(described_class) do
        def parsed(*args)
          _, _, args = args
          @custom_called = args
        end
      end.new(options: options)

      custom_app.subscribe(custom_app)
      custom_app.on(:parsed) do |*args|
        _, _, args = args
        custom_app.instance_variable_set(:@block_called, args)
      end
      expect { custom_app.parse(["-h"]) }.to output(/Test app/).to_stdout
      expect(custom_app.instance_variable_get(:@custom_called)).to eq []
      expect(custom_app.instance_variable_get(:@block_called)).to eq []
    end
  end

  describe "#run" do
    it "raises NotImplementedError" do
      expect { app.run }.to raise_error(NotImplementedError, /Subclasses must implement `run`/)
    end
  end
end
