# frozen_string_literal: true

require "tmpdir"

require "spec_helper"
require "elx_app/path_utils"

RSpec.describe ElxApp::PathUtils do
  let(:tmpdir) { Dir.mktmpdir }
  let(:demo) do
    Class.new do
      include ElxApp::PathUtils
    end
  end
  let(:instance) { demo.new }

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#path_readable?" do
    it "returns true for readable directory" do
      expect(instance.path_readable?(tmpdir)).to be true
    end

    it "raises Error for nil path" do
      expect { instance.path_readable?(nil) }.to raise_error(ElxApp::Error, /Invalid path/)
    end
  end

  describe "#path_writable?" do
    it "returns true for writable directory" do
      expect(instance.path_writable?(tmpdir)).to be true
    end

    it "returns false for root directory" do
      expect(instance.path_writable?("/")).to be false
    end

    it "raises Error for nil path" do
      expect { instance.path_writable?(nil) }.to raise_error(ElxApp::Error, /Invalid path/)
    end
  end

  describe "#ensure_writable_file" do
    it "returns file path if file exists and is writable" do
      file = File.join(tmpdir, "test.txt")
      File.write(file, "test")
      expect(instance.ensure_writable_file(file)).to eq file
    end

    it "creates parent directory and returns file path if directory does not exist" do
      file = File.join(tmpdir, "subdir/test.txt")
      expect(instance.ensure_writable_file(file)).to eq file
      expect(Dir.exist?(File.dirname(file))).to be true
    end

    it "raises PathNotWritableError if parent directory is not writable" do
      file = "/root/test.txt"
      expect do
        instance.ensure_writable_file(file)
      end.to raise_error(ElxApp::PathNotWritableError, /root/)
    end

    it "raises Error for nil file path" do
      expect do
        instance.ensure_writable_file(nil)
      end.to raise_error(ElxApp::Error, /Invalid file path/)
    end
  end

  describe "#ensure_writable_path" do
    it "creates a path if required" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "test_writable")
        expect(instance.ensure_writable_path(path)).to eq path
      end
    end

    it "ensure the path is writable" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "test_writable2")
        instance.ensure_writable_path(path)
        expect(File.writable?(path)).to be true
      end
    end
  end

  describe "#ensure_readable_path" do
    it "create readable path if required" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "test_readable")
        expect(instance.ensure_readable_path(path)).to eq path
      end
    end

    it "ensure the path is readable" do
      Dir.mktmpdir do |dir|
        path = File.join(dir, "test_readable2")
        instance.ensure_readable_path(path)
        expect(File.readable?(path)).to be true
      end
    end
  end

  describe "#config_path" do
    context "when env BASE_PATH exist" do
      it "return the defined ENV['BASE_PATH']" do
        env_path = ENV.fetch("BASE_PATH")
        expect(instance.config_path("spec")).to include(env_path)
      end
    end

    context "when ENV['BASE_PATH'] dont exist" do
      it "return default path based on user" do
        ENV.delete("BASE_PATH")
        base_cfg = File.join(Dir.home, ".config")
        expect(instance.config_path("spec")).to include(base_cfg)
      end
    end
  end

  describe "#log_path" do
    context "when ENV['LOG_PATH'] exist" do
      it "return the defined ENV['LOG_PATH']" do
        env_path = ENV.fetch("LOG_PATH")
        expect(instance.log_path("spec")).to include(env_path)
      end
    end

    context "when ENV['LOG_PATH'] dont exist" do
      it "return default path based on user" do
        ENV.delete("LOG_PATH")
        base_log = File.join(Dir.home, "log")
        expect(instance.log_path("spec")).to include(base_log)
      end
    end
  end
end
