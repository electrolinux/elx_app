# frozen_string_literal: true

require "fileutils"
require "tmpdir"
require "yaml"

require "spec_helper"

require "elx_app/config_builder"

def create_demo(path)
  FileUtils.mkdir_p(File.join(path, "items"))
  (1..10).each do |x|
    File.write("#{path}/items/item#{x}.yml", <<~YML)
      ---
      name: item_#{x}
      price: #{20 * x}.00
    YML
  end
end

module ElxApp
  RSpec.describe ConfigBuilder do
    let(:cb_class) { described_class }

    describe "#initialize" do
      context "when missing or invalid arg" do
        it "raise ArgumentError if no name" do
          expect do
            cb_class.new(filename: "demo.yml", glob: "*.yml")
          end.to raise_error(ArgumentError)
        end

        it "raise ArgumentError if invalid name" do
          expect do
            cb_class.new(name: "x.y.z", filename: "demo.yml", glob: "*.yml")
          end.to raise_error(ArgumentError)
        end

        it "raise ArgumentError if no filename" do
          expect do
            cb_class.new(name: "demo", glob: "*.yml")
          end.to raise_error(ArgumentError)
        end

        it "raise ArgumentError if invalid filename" do
          expect do
            cb_class.new(name: "demo", filename: "demo.ini", glob: "*.yml")
          end.to raise_error(ArgumentError)
        end

        it "raise ArgumentError if no glob" do
          expect do
            cb_class.new(name: "demo", filename: "demo.yml", glob: nil)
          end.to raise_error(ArgumentError)
        end

        it "raise ArgumentError if invalid glob" do
          expect do
            cb_class.new(name: "demo", filename: "demo.yml", glob: "*.ini")
          end.to raise_error(ArgumentError)
        end
      end

      context "when everything fine" do
        let(:tmpdir) { Dir.mktmpdir }

        before do
          create_demo(tmpdir)
        end

        after do
          FileUtils.rm_rf(tmpdir)
        end

        it "create the specified config file" do
          filename = "#{tmpdir}/items.yml"
          cb_class.new(name: "items", filename: filename, glob: "**/*.yml")
          expect(File.exist?(filename)).to be true
        end

        it "create the specified config file version 2" do
          filename = "#{tmpdir}/items.yml"
          cb_class.new(name: "items", filename: filename, glob: "items/*.yml")
          expect(File.exist?(filename)).to be true
        end

        it "file is a readable YAML file" do
          filename = "#{tmpdir}/items.yml"
          cb_class.new(name: "items", filename: filename, glob: "**/*.yml")
          expect(YAML.load_file(filename)).to be_a(Hash)
        end

        it "file contains all gathered entries" do
          filename = "#{tmpdir}/items.yml"
          cb_class.new(name: "items", filename: filename, glob: "**/*.yml")
          settings = YAML.load_file(filename)
          expect(settings["items"].size).to eq 10
          expect(settings["items"]).to all(be_a(Hash))
        end
      end
    end
  end
end
