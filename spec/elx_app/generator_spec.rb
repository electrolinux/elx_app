# frozen_string_literal: true

require "tmpdir"

require "spec_helper"
require "elx_app/generator"

class Renderer
  attr_reader :config

  def initialize(config)
    config.set("foo.bar", "rendered")
    config.set("path", "inline renderer")
    @config = config
  end

  def before_render(event)
    # pp event; exit 0
    # event[:config] = @config
    event[:rendered] = "Hook from before_render event"
  end

  def after_render(event)
    event[:rendered] = "Decorated render: #{event[:rendered]}"
  end
end

RSpec.describe ElxApp::Generator do
  let(:tmpdir) { Dir.mktmpdir }
  let(:config) { ElxApp::Config.new({ "foo" => { "bar" => "baz" }, "path" => tmpdir, "configfile" => "test.yml" }) }
  let(:template_file) { File.join(tmpdir, "test.mustache") }

  before do
    File.write(template_file, "Hello, {{foo.bar}} from {{path}}")
  end

  after do
    FileUtils.rm_rf(tmpdir)
  end

  describe "#initialize" do
    it "raises ArgumentError for invalid config" do
      expect { described_class.new(template_file: template_file, config: nil) }
        .to raise_error(ArgumentError, /Config must be an ElxApp::Config instance/)
    end

    it "raises ArgumentError for missing template file" do
      expect { described_class.new(template_file: "", config: config) }
        .to raise_error(ArgumentError, /Template file must be specified/)
    end

    it "raises FileNotFoundError for non-existent template file" do
      expect { described_class.new(template_file: "/nonexistent.mustache", config: config) }
        .to raise_error(ElxApp::FileNotFoundError, /nonexistent.mustache/)
    end
  end

  describe "#render" do
    it "renders the template with config data" do
      generator = described_class.new(template_file: template_file, config: config)
      expect(generator.render).to eq "Hello, baz from #{tmpdir}"
    end

    context "when using successful events" do
      let(:renderer) { Renderer.new(config) }
      let(:ev_gen) { described_class.new(template_file: template_file, config: config) }

      before do
        ev_gen.subscribe(renderer)
      end

      it "render the template via :before_render event" do
        expect(ev_gen.render).to match(/Hook from before_render event/)
      end

      it "update the template via :after_render event" do
        expect(ev_gen.render).to match(/Decorated render: /)
      end
    end
  end
end
