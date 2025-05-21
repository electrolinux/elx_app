# frozen_string_literal: true

require "fileutils"

require "elx_app"

module ElxApp
  ##
  # Helper to manage paths for CLI application (config, log)
  #
  module PathUtils
    def path_readable?(path)
      raise Error, "Invalid path (nil) given to '#{__method__}'" if path.nil?

      Dir.exist?(path) && File.readable?(path)
    end

    def path_writable?(path)
      raise Error, "Invalid path (nil) given to '#{__method__}'" if path.nil?

      return true if Dir.exist?(path) && File.writable?(path)
      return false if path == "/"

      path_writable?(File.dirname(path))
    end

    def ensure_writable_file(file)
      raise Error, "Invalid file path (nil) given to '#{__method__}'" if file.nil?

      return file if File.exist?(file) && File.writable?(file)

      FileUtils.mkdir_p(File.dirname(file))
      raise PathNotWritableError, File.dirname(file) unless File.writable?(File.dirname(file))

      file
    end

    def ensure_writable_path(path)
      raise Error, "Invalid path (nil) given to '#{__method__}'" if path.nil?

      FileUtils.mkdir_p(path)
      raise PathNotWritableError, path unless File.writable?(path)

      path
    end

    def ensure_readable_path(path)
      raise Error, "Invalid path (nil) given to '#{__method__}'" if path.nil?

      ensure_writable_path(path) unless Dir.exist?(path)
      raise PathNotReadableError, path unless File.readable?(path)

      path
    end

    def env_base_path?
      ENV.key?("BASE_PATH") &&
        !ENV["BASE_PATH"].empty? &&
        File.readable?(ENV.fetch("BASE_PATH", nil))
    end

    def env_log_path?
      ENV.key?("LOG_PATH") &&
        !ENV["LOG_PATH"].empty? &&
        File.writable?(ENV.fetch("LOG_PATH", nil))
    end

    def config_path(app_name)
      return ENV.fetch("BASE_PATH", nil) if env_base_path?
      return "/etc/#{app_name}" if Process.uid.zero?

      File.join(Dir.home, ".config/#{app_name}")
    end

    def log_path(app_name)
      return ENV.fetch("LOG_PATH", nil) if env_log_path?
      return "/var/log/#{app_name}" if Process.uid.zero?

      File.join(Dir.home, "log/#{app_name}")
    end
  end
end
