# frozen_string_literal: true

require "mustache"
require "wisper"

require "elx_app/config"
require "elx_app/path_utils"

# Template generator for CLI applications
#
module ElxApp
  ##
  # Generate content based on a mustache template and a config
  #
  class Generator
    include PathUtils
    include Wisper::Publisher

    attr_reader :template, :config

    # @param template_file [String] Path to the Mustache template file
    # @param config [ElxApp::Config] Configuration object with template data
    def initialize(template_file:, config:)
      raise ArgumentError, "Config must be an ElxApp::Config instance" unless config.is_a?(ElxApp::Config)
      raise ArgumentError, "Template file must be specified" if template_file.nil? || template_file.empty?

      @template = load_template(template_file)
      @config   = config
    end

    # Renders the template with the configuration data
    # @return [String] Rendered template output
    def render
      event = { template: template, config: config, rendered: nil }
      broadcast(:before_render, event)
      rendered = event.fetch(:rendered).nil? ? Mustache.render(template, config.settings) : event.fetch(:rendered)
      event = { rendered: rendered }
      broadcast(:after_render, event)
      event[:rendered]
    end

    private

    # Loads the template file
    # @param file [String] Path to the template file
    # @return [String] Template content
    def load_template(file)
      ensure_readable_path(File.dirname(file))
      raise FileNotFoundError, file unless File.exist?(file) && File.readable?(file)

      File.read(file)
    end
  end
end
