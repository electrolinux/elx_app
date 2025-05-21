# frozen_string_literal: true

require "yaml"

require "elx_app"
require "elx_app/config_builder"

module ElxApp
  ##
  # ConfigLoader: load config parts from other files
  #
  module ConfigLoader
    FILE_LOADER_PREFIX  = "file:"
    FILE_BUILDER_PREFIX = "builder:"

    def self.included(base)
      base.class_eval do
        # Warn if the including class doesn't initialize required attributes.
        def initialize(*)
          super
          raise Error, "Missing @loaders initialization!" unless defined?(@loaders)
          raise Error, "Missing @builders initialization!" unless defined?(@builders)
          raise Error, "Missing @settings initialization!" unless defined?(@settings)
        end
      end
    end

    def file_loader?(value)
      value.is_a?(String) && value.start_with?(FILE_LOADER_PREFIX)
    end

    def file_builder?(value)
      value.is_a?(String) && value.start_with?(FILE_BUILDER_PREFIX)
    end

    def loader_or_builder?(value)
      file_loader?(value) || file_builder?(value)
    end

    def resolve_loaders(hash, prefix = "")
      hash.each do |key, value|
        full_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
        if loader_or_builder?(value)
          if file_builder?(value)
            add_loader_from_builder(key, value, prefix)
          else
            path = value.sub(FILE_LOADER_PREFIX, "")
            full_path = File.join(settings["path"] || Dir.pwd, path)
            add_loader(key, full_path, prefix)
          end
        elsif value.is_a?(Hash)
          resolve_loaders(value, full_key)
        end
      end
    end

    def add_loader(key, full_path, prefix = "")
      unless File.exist?(full_path) && File.readable?(full_path)
        raise LoaderFileNotFoundError, "Loader file '#{full_path}' not found or unreadable"
      end

      full_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
      loader = @loaders.key?(full_path) ? @loaders[full_path] : Config.from_file(full_path)
      # ensure loader has specified key
      raise LoaderKeyNotFoundError, "Loader file '#{full_path}' miss a '#{key}' key" unless loader.key?(key)

      # replace @settings[full_key]
      set(full_key, loader.get(key))

      # only add first loader for each full_path
      # -- was it an undetected bug? (seems not !?)
      # @loaders[full_key] = loader unless @loaders.key?(full_path)
      @loaders[full_key] = loader unless @loaders.key?(full_key)
    end

    def add_loader_from_builder(key, value, prefix = "")
      # builder:<filename>[:<glob>]
      # e.g:
      # - "builder:sites.yml:sites/*.yml"
      # - "builder:items.yml"
      specs = value.sub(FILE_BUILDER_PREFIX, "")
      file, glob = specs.split(":")
      glob ||= "**/*.yml"
      full_key = prefix.empty? ? key.to_s : "#{prefix}.#{key}"
      full_path = File.join(settings["path"] || Dir.pwd, file)
      ConfigBuilder.new(name: full_key, filename: full_path, glob: glob)
      add_loader(key, full_path, prefix)
      return if @builders.key?(full_key)

      @builders[full_key] = {
        loader: loaders[full_key],
        builder: { file: file, glob: glob }
      }
    end

    def write_loaders(new_settings)
      loaders_written = {}
      @loaders.each do |full_key, loader|
        file_path = loader.get("path")
        unless loaders_written.key?(file_path)
          write_loader_from_key(loader, full_key)
          loaders_written[file_path] = loader
        end
        if @builders.key?(full_key)
          overwrite_builder_key_value(full_key, new_settings)
        else
          cfg_file = loader.get("configfile")
          value = cfg_file.gsub("#{get("path")}/", "file:")
          overwrite_loader_key_value(full_key, value, new_settings)
        end
      end
    end

    def overwrite_loader_key_value(full_key, loader, new_settings)
      for_builder = @builders.key?(full_key)
      cfg_file    = loader.get("configfile")
      replace     = for_builder ? "builder:" : "file:"
      value_file  = cfg_file.gsub("#{get("path")}/", replace)
      return update_loader_key(full_key, value_file, new_settings) unless for_builder

      glob = @builders[full_key][glob]
      value = "#{value_file}:#{glob}"
      update_loader_key(full_key, value, new_settings)
    end

    def update_loader_key(full_key, value, new_settings)
      keys = full_key.to_s.split(".")
      last = keys.pop
      hash = keys.reduce(new_settings) { |h, k| h[k] ||= {} }
      hash[last] = value
    end

    def write_loader_from_key(loader, key)
      loader.set(key.split(".").pop, get(key))
      loader.write
    end
  end
end
