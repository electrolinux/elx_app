# frozen_string_literal: true

require "open3"

require "elx_app"
require "elx_app/log"

module ElxApp
  # Helper class to run external commands and pipelines with logging and error handling.
  class Cli
    include Log

    attr_reader :logger, :env, :output, :error, :status

    # Initializes a Cli instance.
    # @param logger [Logger, nil] Logger for command execution (default: nil).
    # @param env [Hash] Environment variables for commands (default: { "LC_ALL" => "C" }).
    def initialize(logger: nil, env: { "LC_ALL" => "C" })
      @logger = logger
      @env = env
    end

    # Runs a single command and captures its output, error, and status.
    # @param command [String, Array<String>] Command to run (string or array of arguments).
    # @param raise_on_error [Boolean] Raise CliError on failure (default: true).
    # @param log_level [String] Log level for command execution (default: "debug").
    # @param log_return [Boolean] Log command output (default: false).
    # @param opts [Hash] Additional options for Open3.capture3 (e.g., chdir, stdin_data).
    # @return [String] Command output (stdout).
    # @raise [CliError] If raise_on_error is true and the command fails.
    def run(*command, raise_on_error: true, log_level: "debug", log_return: false, **opts)
      cmd = normalize_command(command)
      with_logging("Cli::run #{cmd.join(" ")}", level: log_level, log_return: log_return) do
        @output, @error, @status = Open3.capture3(env, *cmd, **opts)
        raise CliError, "Command failed: #{@error}", @output if raise_on_error && !status.success?

        @output.force_encoding("UTF-8")
      end
    end

    # Runs a pipeline of commands, piping output from one to the next.
    # @param commands [Array<String, Array<String>>] Commands to run in sequence.
    # @param raise_on_error [Boolean] Raise CliError on failure (default: true).
    # @param log_level [String] Log level for pipeline execution (default: "debug").
    # @param opts [Hash] Additional options for Open3.pipeline_r (e.g., chdir).
    # @return [String] Output of the last command in the pipeline.
    # @raise [CliError] If raise_on_error is true and any command fails.
    def pipeline(*commands, raise_on_error: true, log_level: "debug", **opts)
      return empty_output if commands.empty?

      cmds = normalize_pipeline(commands)
      execute_pipeline(cmds, raise_on_error, log_level, opts)
    rescue Errno::ENOENT => e
      handle_pipeline_error(e.message, raise_on_error, log_level)
    end

    private

    # Normalizes a command to an array of non-empty strings.
    # @param command [String, Array<String>] Command to normalize.
    # @return [Array<String>] Normalized command.
    # @raise [CliError] If the command is empty.
    def normalize_command(command)
      cmd = Array(command).flatten.reject(&:empty?).map(&:to_s)
      raise CliError, "Empty command" if cmd.empty?

      cmd
    end

    # Normalizes a pipeline to an array of commands.
    # @param commands [Array<String, Array<String>>] Commands to normalize.
    # @return [Array<Array<String>>] Normalized pipeline.
    # @raise [CliError] If fewer than two commands are provided.
    def normalize_pipeline(commands)
      pipes = split_commands(commands)
      cmds = Array(pipes).reject(&:empty?)
      raise CliError, "Pipeline requires at least 2 commands" if cmds.length < 2

      cmds
    end

    # Splits commands into a pipeline, handling pipe characters in strings.
    # @param cmds [Array<String, Array<String>>] Commands to split.
    # @return [Array<Array<String>>] Array of normalized commands.
    def split_commands(cmds)
      return pipes_from_string(cmds[0]) if cmds.length == 1 && cmds[0].is_a?(String) && cmds[0].include?("|")

      Array(cmds).map { |p| normalize_command(p) }
    end

    # Splits a string containing pipe characters into commands.
    # @param command [String] Command string with pipes.
    # @return [Array<Array<String>>] Array of normalized commands.
    def pipes_from_string(command)
      command.split(/\s*\|\s*/).map { |p| normalize_command(p) }
    end

    def empty_output
      String.new.force_encoding("UTF-8")
    end

    def execute_pipeline(cmds, raise_on_error, log_level, opts)
      pipeline_str = cmds.map { |c| c.join(" ") }.join(" | ")
      with_logging("Cli::pipeline [#{pipeline_str}]", level: log_level) do
        stdout, statuses = Open3.pipeline_r(*cmds.map { |c| [env, *c] }, **opts)
        process_pipeline_result(stdout, statuses, raise_on_error, log_level)
      end
    end

    def process_pipeline_result(stdout, statuses, raise_on_error, log_level)
      @output = stdout.read
      @status = statuses.last&.value
      return @output.force_encoding("UTF-8") if statuses.all? { |s| s.value.success? }

      handle_pipeline_failure(statuses, raise_on_error, log_level)
    end

    def handle_pipeline_failure(statuses, raise_on_error, log_level)
      @error = statuses.map { |s| s.value.to_s }.join("; ")
      error_message = "Pipeline failed: #{@error || "unknown error"}"
      raise CliError, error_message, @output if raise_on_error

      logger&.public_send(log_level, error_message)
      empty_output
    end

    def handle_pipeline_error(message, raise_on_error, log_level)
      @error = "Pipeline failed: #{message}"
      logger&.public_send(log_level, @error) unless raise_on_error
      raise CliError, @error, @output if raise_on_error

      empty_output
    end
  end
end
