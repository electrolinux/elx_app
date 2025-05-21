# frozen_string_literal: true

require "logger"
require "tmpdir"

require "elx_app"
require "elx_app/cli"

module ElxApp
  RSpec.describe Cli do
    let(:logger) { instance_double(Logger) }
    let(:cli) { described_class.new(logger: logger) }
    let(:expected_string1) { "This is a Ruby one liner.\n" }
    let(:one_liner1) { "puts '#{expected_string1.chomp}'" }
    let(:cmd1) { %w[ruby -e] << one_liner1 }
    let(:cmd2) { %w[grep -w Ruby] }

    before do
      allow(logger).to receive(:add)
      allow(logger).to receive(:info)
      allow(logger).to receive(:debug)
      allow(logger).to receive(:warn)
      allow(logger).to receive(:error)
    end

    describe "#run" do
      context "when there is no error" do
        it "returns output of a basic shell command" do
          expect(cli.run("pwd").chomp).to eq(Dir.pwd)
        end

        it "returns output of a ruby one-liner" do
          expect(cli.run(cmd1)).to eq(expected_string1)
        end

        it "passes along ENV variables" do
          text = "This is working\n"
          env = { "RSPEC_ENV_TEST" => text.chomp }
          _cli = described_class.new(env: env, logger: logger)
          expect(_cli.run(%w[ruby -e], "puts ENV['RSPEC_ENV_TEST']")).to eq(text)
        end

        it "logs cmdline to logger with debug" do
          cli.run(%w[echo Hello, World!])
          expect(logger).to have_received(:debug).with(/Cli::run echo Hello, World!/)
        end
      end

      context "when there is a failure or error" do
        it "raises appropriate error" do
          expect { cli.run("false") }.to raise_error(CliError, /Command failed/)
        end

        it "logs the failure" do
          expect { cli.run("false") }.to raise_error(CliError)
          expect(logger).to have_received(:error)
        end

        it "handles empty command" do
          expect { cli.run("") }.to raise_error(CliError, /Empty command/)
        end
      end

      context "with log_return" do
        it "logs command and output to logger with debug" do
          cli.run(%w[echo Hello, World!], log_return: true)
          expect(logger).to have_received(:debug).with(/Cli::run echo Hello, World!/).ordered
          expect(logger).to have_received(:debug).with(a_string_including("Hello, World!")).at_least(:once)
        end
      end
    end

    describe "#pipeline" do
      let(:cmd1) { %w[ls spec/elx_app] }
      let(:cmd2) { %w[grep cli_spec.rb] }

      context "when no error or failure" do
        it "runs commands in pipes" do
          expect(cli.pipeline(cmd1, cmd2).chomp).to eq("cli_spec.rb")
        end

        it "logs with debug" do
          cli.pipeline(cmd1, cmd2)
          expect(logger).to have_received(:debug).with(%r{Cli::pipeline \[ls spec/elx_app \| grep cli_spec\.rb\]})
        end

        it "accepts a string with pipe character" do
          expect(cli.pipeline("ls spec/elx_app | grep cli_spec.rb | wc -l").chomp).to eq("1")
        end
      end

      context "when error or failure" do
        it "ensures having enough commands" do
          expect { cli.pipeline("ls -alh") }.to raise_error(CliError, /Pipeline requires at least 2 commands/)
        end

        it "raises appropriate error for non-existent command" do
          bad = %w[greep Ruby]
          expect do
            cli.pipeline(cmd1, bad)
          end.to raise_error(CliError, /Pipeline failed: No such file or directory - greep/)
        end

        it "logs error" do
          bad = %w[greep Ruby]
          expect { cli.pipeline(cmd1, bad) }.to raise_error(CliError)
          expect(logger).to have_received(:error)
        end

        it "returns empty string and logs error when raise_on_error is false" do
          bad = %w[greep Ruby]
          result = cli.pipeline(cmd1, bad, raise_on_error: false)
          expect(result).to eq("")
          expect(logger).to have_received(:debug).with(/Cli::pipeline/)
          expect(logger).to have_received(:debug).with(/Pipeline failed: No such file or directory - greep/)
        end
      end
    end
  end
end
