# frozen_string_literal: true

require "logger"
require "fileutils"

require "elx_app/log"

module ElxApp
  RSpec.describe Log do
    let(:logger) { instance_double(Logger) }
    let(:demo) { QuickLog.new(logger: logger) }

    describe "::with_logging" do
      before do
        # Stub Logger methods to avoid "method not implemented" errors
        allow(logger).to receive(:add) # Required for respond_to?(:add)
        allow(logger).to receive(:info)
        allow(logger).to receive(:debug)
        allow(logger).to receive(:error)
      end

      it "logs before running a block" do
        msg = "Log::with_logging, Test one"
        expect(logger).to receive(:info).with(">>> Run '#{msg}'")
        demo.with_logging(msg) { "Test one" }
      end

      it "returns the block's value" do
        msg = "Log::with_logging, Test two"
        expect(logger).to receive(:info).with(">>> Run '#{msg}'")
        value = demo.with_logging(msg) { "Test two" }
        expect(value).to eq "Test two"
      end

      it "allows specifying logging level" do
        msg = "Log::with_logging, Test three"
        expect(logger).to receive(:debug).with(">>> Run '#{msg}'")
        demo.with_logging(msg, level: :debug) { "Test three" }
      end

      it "logs return value when requested" do
        msg = "Log::with_logging, Test four"
        expect(logger).to receive(:debug).with(">>> Run '#{msg}'")
        expect(logger).to receive(:debug).with(/<<< Return Test four \(\d+\.\d+s\)/)
        demo.with_logging(msg, level: :debug, log_return: true) { "Test four" }
      end

      it "logs and re-raises a SystemCallError" do
        msg = "Making a system call error"
        expect(logger).to receive(:info).with(">>> Run '#{msg}'")
        expect(logger).to receive(:error).with(/!!! SysCallError '#{msg}' - No such file or directory/)
        expect do
          demo.with_logging(msg) { raise Errno::ENOENT, "No such file or directory" }
        end.to raise_error(Errno::ENOENT, /No such file or directory/)
      end

      it "logs and re-raises a StandardError" do
        msg = "Making a standard error"
        expect(logger).to receive(:info).with(">>> Run '#{msg}'")
        expect(logger).to receive(:error).with(/!!! Failed '#{msg}' - Something went wrong/)
        expect do
          demo.with_logging(msg) { raise StandardError, "Something went wrong" }
        end.to raise_error(StandardError, "Something went wrong")
      end

      it "raises when no block is given" do
        expect { demo.with_logging("without a block") }
          .to raise_error(StandardError, "Log::with_logging: No block given")
      end

      context "when logger does not respond to :add" do
        let(:invalid_logger) { instance_double(Object) }
        let(:invalid_demo) { QuickLog.new(logger: invalid_logger) }

        it "raises 'Logger not initialized'" do
          expect { invalid_demo.with_logging("testing") { "bad" } }
            .to raise_error(StandardError, "Logger not initialized")
        end
      end

      context "when logger is nil" do
        let(:nil_demo) { NilLog.new }

        it "raises 'Logger not initialized'" do
          expect(nil_demo.logger).to be_nil # Debug check
          expect { nil_demo.with_logging("testing") { "bad" } }
            .to raise_error(StandardError, "Logger not initialized")
        end
      end
    end
  end
end
