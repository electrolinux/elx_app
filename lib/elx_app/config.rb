# frozen_string_literal: true

require "yaml"
require "elx_app/path_utils"
require "elx_app/config_loader"

module ElxApp
  # Module for handling nested key navigation and assignment
  module KeyNavigation
    private

    def navigate_keys(keys, current, default)
      keys.each do |key|
        next_value = access_key(key, current)
        return default unless next_value

        current = next_value
      end
      current.nil? ? default : current
    end

    def access_key(key, current)
      case current
      when Array
        return unless key.match?(/\A\d+\z/)

        current[key.to_i] if key.to_i < current.length
      when Hash
        current[key] if current.key?(key)
      else
        raise InvalidKeyError, "Cannot access '#{key}' in #{current.class}"
      end
    end

    def navigate_and_set(keys, current, value)
      last_key = keys.pop
      keys.each do |key|
        current = access_or_create_container(key, current, keys.join("."))
      end
      validate_hash_container(current, last_key, keys.join("."))
      current[last_key] = value
    end

    def access_or_create_container(key, current, full_key)
      case current
      when Array
        raise InvalidKeyError, "Cannot set value in array at index '#{key}' in path '#{full_key}'" if key.match?(/\A\d+\z/)

        raise InvalidKeyError, "Cannot access '#{key}' in #{current.class} at path '#{full_key}'"
      when Hash
        current[key] ||= {}
      else
        raise InvalidKeyError, "Cannot access '#{key}' in #{current.class} at path '#{full_key}'"
      end
    end

    def validate_hash_container(current, key, full_key)
      return if current.is_a?(Hash)

      raise InvalidKeyError, "Cannot set '#{key}' in #{current.class} at path '#{full_key}'"
    end
  end

  # Manages configuration for CLI applications, supporting nested keys and file-based settings.
  #
  # @example Loading a config from a YAML file
  #   config = ElxApp::Config.from_file("config.yml")
  #   config.get("foo.bar") # => "baz"
  class Config
    include PathUtils
    include ConfigLoader
    include KeyNavigation

    attr_reader :settings, :loaders, :builders

    VAR_CONFIGFILE = "configfile"

    # Initializes a new Config instance with optional settings and app name.
    #
    # @param settings [Hash] Initial configuration settings (default: {}).
    # @param app [String] Application name (default: derived from $PROGRAM_NAME).
    # @param default_settings [Hash, nil] Default settings to merge with settings.
    # @return [Config] A new Config instance.
    def initialize(settings = {}, app: nil, default_settings: nil)
      @app = app || File.basename($PROGRAM_NAME, File.extname($PROGRAM_NAME))
      @settings = default_settings&.deep_merge(settings) || settings
      @loaders = {}
      @builders = {}
      resolve_loaders(@settings)
    end

    def self.from_file(cfg_file, must_exist: false)
      validate_file_access(cfg_file, must_exist)
      return new_from_file(cfg_file) unless file_accessible?(cfg_file)

      build_config_from_yaml(cfg_file)
    end

    def self.new_from_file(filename)
      new.ensure_writable_file(filename)
      new.tap do |cfg|
        cfg.set("filename", File.dirname(filename))
        cfg.set("configfile", filename)
      end
    end

    def key?(key)
      keys = key.to_s.split(".")
      current = settings
      keys.each do |k|
        if current.is_a?(Array) && k =~ /\A\d+\z/
          index = k.to_i
          return false unless index < current.length

          current = current[index]
        elsif current.is_a?(Hash)
          return false unless current.key?(k)

          current = current[k]
        else
          return false
        end
      end
      true
    end

    # Retrieves a value for a given key, with an optional default.
    #
    # @param key [String, Symbol] The key to retrieve (supports dot notation, e.g., "foo.bar").
    # @param default [Object, nil] Value to return if key is missing (default: nil).
    # @return [Object, nil] The value or default if key is missing.
    # @raise [InvalidKeyError] If the key cannot be accessed in the settings structure.
    def get(key, default = nil)
      keys = key.to_s.split(".")
      navigate_keys(keys, settings, default)
    end

    def set(key, value)
      keys = key.to_s.split(".")
      navigate_and_set(keys, settings, value)
    end

    def write
      raise "Config is missing a valid (writable) '#{VAR_CONFIGFILE}' entry." unless writable_configfile?

      begin
        new_settings = settings.dup
        write_loaders(new_settings)
        File.write(settings[VAR_CONFIGFILE], YAML.dump(new_settings))
      rescue Errno::EACCES => e
        raise "Cannot write to config file '#{settings[VAR_CONFIGFILE]}': #{e.message}"
      end
    end

    def self.validate_file_access(cfg_file, must_exist)
      return unless must_exist && !file_accessible?(cfg_file)

      raise ConfigFileNotFoundError, "File '#{cfg_file}' not found or unreadable"
    end

    def self.file_accessible?(cfg_file)
      File.exist?(cfg_file) && File.readable?(cfg_file)
    end

    def self.build_config_from_yaml(cfg_file)
      data = load_yaml_file(cfg_file)
      enrich_config_data(data, cfg_file)
      new(data)
    rescue Psych::SyntaxError => e
      raise "Failed to parse YAML file '#{cfg_file}': #{e.message}"
    end

    def self.load_yaml_file(cfg_file)
      data = YAML.load_file(cfg_file)
      raise "Invalid YAML: must be a Hash" unless data.is_a?(Hash)

      data
    end

    def self.enrich_config_data(data, cfg_file)
      data["path"] = File.dirname(cfg_file) unless data.key?("path")
      data["configfile"] = cfg_file unless data.key?("configfile")
    end

    private

    def writable_configfile?
      return false unless settings.key?("configfile")

      File.writable?(settings["configfile"])
    end
  end
end
