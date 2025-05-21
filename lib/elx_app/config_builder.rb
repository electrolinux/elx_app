# frozen_string_literal: true

require "yaml"

# require "elx_app/config"
require "elx_app/path_utils"

module ElxApp
  ##
  # ConfigBuilder: build a config file from a glob
  #
  class ConfigBuilder
    include PathUtils

    attr_reader :name, :filename, :glob, :files

    def initialize(name:, filename:, glob: "**/*.yml")
      check_args(name: name, filename: filename, glob: glob)
      @name     = name
      @filename = filename
      @glob     = glob
      @files    = []
      build_config
    end

    def check_args(name:, filename:, glob:)
      raise ArgumentError, "Missing or bad argument :name" unless name && check_name(name)
      raise ArgumentError, "Missing or bad argument :filename" unless filename && check_file(filename)
      raise ArgumentError, "Missing or bad argument :glob" unless glob && check_glob(glob)
    end

    def build_config
      ensure_writable_file(filename)
      load_files
      content = []
      files.each do |file|
        entry = YAML.load_file(file)
        content.push(entry)
      rescue Psych::SyntaxError => e
        raise Error, "Failed to parse YAML file '#{file}': #{e.message}"
      end
      save_config(content)
    end

    def save_config(content)
      settings = {
        name => content,
        "path" => File.dirname(filename),
        "configfile" => filename
      }
      yaml = YAML.dump(settings)
      header = <<~HEADER
        # Don't modify this file, it will be automatically recreated
        # from '#{@glob}'
        # (excluding '#{filename}')
      HEADER
      File.write(filename, "#{header}#{yaml}")
      settings
    end

    private

    def check_name(name)
      !name.nil? && name.match(/[a-z]+[a-z0-9_]+/)
    end

    def check_file(filename)
      filename.end_with?(".yml")
    end

    def check_glob(glob)
      %w[* ?].any? { |char| glob.include?(char) } && glob.end_with?(".yml")
    end

    def load_files
      @glob = File.join(File.dirname(filename), glob)
      files = Dir.glob(@glob).reject { |file| file == filename }
      raise Error, "glob [#{@glob}] yield no files" if files.empty?

      @files = files
    end
  end
end
