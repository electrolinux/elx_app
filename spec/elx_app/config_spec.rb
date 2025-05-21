# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "spec_helper"

def create_demo_config(path, demo)
  create_main_config(path, demo)
  create_config_one(path, demo)
  create_config_two(path, demo)
  create_config_bad1(path, demo)
  create_config_bad2(path, demo)
  create_config_bad3(path, demo)
  create_config_bad4(path, demo)
  create_config_nokey(path)
  create_config_foobar(path)
end

def create_main_config(path, demo)
  cfg_file = File.join(path, demo["main"])
  File.write(cfg_file, <<~YML)
    ---
    level_1:
      loader_1: file:#{demo["one"]}
      subkey:
        loader_2: file:#{demo["two"]}
    path: #{path}
    configfile: #{cfg_file}
    foo:
      bar: baz
  YML
end

def create_config_one(path, demo)
  cfg_one = File.join(path, demo["one"])
  File.write(cfg_one, <<~YML)
    ---
    loader_1:
      foo: foo from loader_one
    path: #{path}
    configfile: #{cfg_one}
  YML
end

def create_config_two(path, demo)
  cfg_two = File.join(path, demo["two"])
  File.write(cfg_two, <<~YML)
    ---
    loader_2:
      bar: bar from loader_two
    path: #{path}
    configfile: #{cfg_two}
  YML
end

def create_config_bad1(path, demo)
  bad1_cfg = File.join(path, demo["bad1"])
  File.write(bad1_cfg, <<~YML)
    ---
    noloader: file:not-a-file.yml
    path: #{path}
    configfile: #{bad1_cfg}
  YML
end

def create_config_bad2(path, demo)
  bad2_cfg = File.join(path, demo["bad2"])
  File.write(bad2_cfg, <<~YML)
    ---
    nokey: file:nokey.yml
    path: #{path}
    configfile: #{bad2_cfg}
  YML
end

def create_config_bad3(path, demo)
  bad3_cfg = File.join(path, demo["bad3"])
  File.write(bad3_cfg, <<~YML)
    ---
    key: value
    other: [invalid: yaml: here]
  YML
end

def create_config_bad4(path, demo)
  bad4_cfg = File.join(path, demo["bad4"])
  File.write(bad4_cfg, <<~YML)
    ---
    - item one
    - item two
  YML
end

def create_config_nokey(path)
  nokey_cfg = File.join(path, "nokey.yml")
  File.write(nokey_cfg, <<~YML)
    ---
    path: #{path}
    configfile: #{nokey_cfg}
  YML
end

def create_config_foobar(path)
  foobar_cfg = File.join(path, "foo")
  File.write(foobar_cfg, <<~YML)
    ---
    foo:
      bar: baz
  YML
end

RSpec.describe ElxApp::Config do
  let(:demo) do
    {
      "main" => "main.yml",
      "one" => "loader_one.yml",
      "two" => "loader_two.yml",
      "foo" => "foobar.yml",
      "bad1" => "bad1.yml",
      "bad2" => "bad2.yml",
      "bad3" => "bad3.yml",
      "bad4" => "bad4.yml"
    }
  end
  let(:config) { described_class.new({ "foo" => { "bar" => { "baz" => "qux" } } }) }
  let(:cfg_path) { Dir.mktmpdir }
  let(:cfg) { described_class.from_file(File.join(cfg_path, demo["main"])) }

  before do
    create_demo_config(cfg_path, demo)
  end

  after do
    FileUtils.rm_rf(cfg_path)
  end

  describe "#get" do
    it "retrieves nested keys" do
      expect(config.get("foo.bar.baz")).to eq "qux"
    end

    it "returns default for missing keys" do
      expect(config.get("missing", "default")).to eq "default"
    end

    context "when no default value given" do
      it "returns nil for missing keys" do
        expect(config.get("missing")).to be_nil
      end
    end

    context "when loaded from file" do
      it "has a path key" do
        expect(cfg.get("path")).to eq cfg_path
      end

      it "has a configfile key" do
        expect(cfg.get("configfile")).to eq File.join(cfg_path, demo["main"])
      end
    end

    context "when contains loaders" do
      it "retrieves key from loader" do
        expect(cfg.get("level_1.loader_1")).to include("foo" => "foo from loader_one")
      end
    end
  end

  describe "#set" do
    it "sets nested keys" do
      config.set("foo.baz", "qux")
      expect(config.get("foo.baz")).to eq "qux"
    end

    context "when contains loaders" do
      it "set key for loader" do
        cfg.set("level_1.loader_1.demo", "set from spec file")
        expect(cfg.get("level_1.loader_1")).to include("demo" => "set from spec file")
      end
    end
  end

  describe "#key?" do
    it "test nested keys existence" do
      expect(config.key?("foo.bar.baz")).to be true
    end

    it "test nested keys absence" do
      expect(config.key?("foo.box")).to be false
    end
  end

  describe "using `file:` loader" do
    it "has a list of loaders" do
      expect(cfg.loaders.any?).to be true
    end

    it "include config key from loaded file" do
      expect(cfg.get("level_1.loader_1.foo")).to eq "foo from loader_one"
    end

    it "raise LoaderFileNotFoundError when file not found" do
      bad1 = File.join(cfg_path, demo["bad1"])
      expect { described_class.from_file(bad1) }.to raise_error(ElxApp::LoaderFileNotFoundError)
    end

    it "raise LoaderKeyNotFoundError when loader miss related key" do
      bad2 = File.join(cfg_path, demo["bad2"])
      expect { described_class.from_file(bad2) }.to raise_error(ElxApp::LoaderKeyNotFoundError)
    end

    it "raise Error for invalid YAML in file" do
      bad3 = File.join(cfg_path, demo["bad3"])
      expect { described_class.from_file(bad3) }.to raise_error(StandardError, /Failed to parse YAML file/)
    end

    it "raise Error when loaded YAML is not a Hash" do
      bad4 = File.join(cfg_path, demo["bad4"])
      expect { described_class.from_file(bad4) }.to raise_error(StandardError, /Invalid YAML: must be a Hash/)
    end
  end
end
