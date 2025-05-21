# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "yaml"
require "spec_helper"
require "elx_app/config_builder"
require "elx_app/config"

module ElxApp
  RSpec.describe "ConfigBuilder and Config Integration with ConfigLoader" do
    let(:tmpdir) { Dir.mktmpdir }
    let(:config_loader_file) { File.join(tmpdir, "config_loader.yml") }
    let(:static_file) { File.join(tmpdir, "static_content.yml") }
    let(:dynamic_file) { File.join(tmpdir, "dynamic_content.yml") }
    let(:glob) { "items/*.yml" }

    # Creates sample YAML files in items/
    def create_sample_files
      FileUtils.mkdir_p(File.join(tmpdir, "items"))
      (1..3).each do |i|
        File.write(File.join(tmpdir, "items", "item#{i}.yml"), <<~YML)
          ---
          name: item#{i}
          price: #{100 * i}.00
        YML
      end
    end

    # Creates static_content.yml
    def create_static_file
      File.write(static_file, <<~YML)
        ---
        static: simple static string
        configfile: #{static_file}
        path: #{tmpdir}
      YML
    end

    # Creates config_loader.yml with file: and builder: loaders
    def create_loader_config
      File.write(config_loader_file, <<~YML)
        ---
        static: file:static_content.yml
        dynamic: builder:dynamic_content.yml:#{glob}
        configfile: #{config_loader_file}
        path: #{tmpdir}
      YML
    end

    before do
      create_sample_files
      create_static_file
      create_loader_config
    end

    after do
      FileUtils.rm_rf(tmpdir)
    end

    describe "loading configuration with file: and builder: loaders" do
      it "loads configurations correctly via file: and builder:" do
        config = Config.from_file(config_loader_file)

        # Verify file: loader
        expect(config.get("static")).to eq("simple static string")

        # Verify builder: loader
        dynamic = config.get("dynamic")
        expect(dynamic).to be_an(Array)
        expect(dynamic).to all(be_a(Hash))
        expect(dynamic[0]["name"]).to eq("item1")
        expect(dynamic[0]["price"]).to eq(100.0)
        expect(dynamic[1]["name"]).to eq("item2")
        expect(dynamic[1]["price"]).to eq(200.0)
        expect(dynamic[2]["name"]).to eq("item3")
        expect(dynamic[2]["price"]).to eq(300.0)

        # Verify path and configfile
        expect(config.get("path")).to eq(tmpdir)
        expect(config.get("configfile")).to eq(config_loader_file)
      end

      it "accesses nested keys in builder: config" do
        config = Config.from_file(config_loader_file)

        expect(config.get("dynamic.0.name")).to eq("item1")
        expect(config.get("dynamic.1.price")).to eq(200.0)
        expect(config.key?("dynamic.2.name")).to be true
        expect(config.key?("dynamic.2.missing")).to be false
      end

      it "raises an error when setting values in array elements" do
        config = Config.from_file(config_loader_file)

        expect { config.set("dynamic.0.status", "active") }
          .to raise_error(ElxApp::InvalidKeyError, /Cannot set value in array at index '0'/)
        expect(config.get("dynamic.0.name")).to eq("item1")
      end

      it "generates a valid dynamic_content.yml with ConfigBuilder" do
        # Load config to trigger builder:
        Config.from_file(config_loader_file)

        # Verify dynamic_content.yml exists
        expect(File.exist?(dynamic_file)).to be true

        # Verify contents of dynamic_content.yml
        config = Config.from_file(dynamic_file)
        expect(config.get("dynamic")).to be_an(Array)
        expect(config.get("dynamic.0.name")).to eq("item1")
        expect(config.get("path")).to eq(tmpdir)
        expect(config.get("configfile")).to eq(dynamic_file)
      end

      it "creates a new config for a missing config file by default" do
        missing_file = File.join(tmpdir, "missing.yml")
        config = Config.from_file(missing_file)

        expect(config).to be_a(ElxApp::Config)
        expect(config.get("filename")).to eq(File.dirname(missing_file))
        expect(config.get("configfile")).to eq(missing_file)
      end

      it "raises an error for a missing config file when must_exist is true" do
        missing_file = File.join(tmpdir, "missing.yml")
        expect { Config.from_file(missing_file, must_exist: true) }
          .to raise_error(ElxApp::ConfigFileNotFoundError, /missing.yml/)
      end

      it "raises an error for invalid YAML" do
        File.write(static_file, "---\ninvalid: yaml: here")
        expect { Config.from_file(config_loader_file) }
          .to raise_error(StandardError, /Failed to parse YAML file/)
      end

      it "raises an error if YAML is not a Hash" do
        File.write(static_file, "---\n- item1\n- item2")
        expect { Config.from_file(config_loader_file) }
          .to raise_error(StandardError, /Invalid YAML: must be a Hash/)
      end
    end
  end
end
