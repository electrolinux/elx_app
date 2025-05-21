# frozen_string_literal: true

require "rainbow"

require "spec_helper"
require "elx_app/display"

module ElxApp
  RSpec.describe Display do
    let(:display) { described_class.new }
    let(:debug_lvl) { described_class.const_get("DEBUG") }
    let(:verbose_lvl) { described_class.const_get("VERBOSE") }
    let(:info_lvl) { described_class.const_get("INFO") }
    let(:quiet_lvl) { described_class.const_get("QUIET") }

    before do
      Rainbow.enabled = true # Ensure colors are applied in tests
    end

    describe "#initialize(level: INFO)" do
      it "provide a default INFO verbosity level" do
        level = display.class.const_get("INFO")
        expect(display.level).to eq level
      end

      it "raise ArgumentError if verbosity level is incorrect" do
        expect { described_class.new(level: "WARNING") }.to raise_error(ArgumentError)
      end
    end

    describe "#output(verbosity, message = nil, color: false)" do
      it "require a verbosity and a message" do
        expect { display.output(info_lvl, "Hello Rspec") }.to output(/Hello Rspec/).to_stdout
      end

      it "add default color by level if color: true" do
        expect do
          display.output(info_lvl, "Colored", color: true)
        end.to output(/\e\[3.*/).to_stdout
      end

      it "try to use given color if color: is not a Boolean" do
        expect do
          display.output(info_lvl, "Custom colored", color: :magenta)
        end.to output(/\e\[3.*/).to_stdout
      end

      it "use default color if given color: is not a Boolean or color code" do
        expect do
          display.output(info_lvl, "Custom colored", color: :not_a_color)
        end.to output(/\e\[3.*/).to_stdout
      end

      it "accept a block if message = nil" do
        expect { display.output(info_lvl) { "From block" } }.to output(/From block/).to_stdout
      end

      it "output nothing if verbosity < @level" do
        expect { display.output(debug_lvl, "debug?") }.not_to output.to_stdout
      end

      it "abstain adding color if message already contains color" do
        message = Rainbow("Red message").red
        expect { display.info(message, color: true) }.to output("#{message}\n").to_stdout
      end
    end

    describe "#quiet(message = nil, color: false)" do
      let(:disp) { described_class.new(level: quiet_lvl) }

      it "output if @level == QUIET" do
        expect { disp.quiet("Quiet message") }.to output(/Quiet message/).to_stdout
      end

      it "output nothing if @level <> QUIET" do
        expect { disp.info("Info") }.not_to output.to_stdout
      end
    end

    describe "#info(message = nil, color: false)" do
      it "output if @level >= INFO" do
        expect { display.quiet("Quiet message") }.to output(/Quiet message/).to_stdout
      end

      it "output nothing if @level < INFO" do
        expect { display.verbose("Verbose?") }.not_to output.to_stdout
      end
    end

    describe "#verbose(message = nil, color: false)" do
      let(:disp) { described_class.new(level: verbose_lvl) }

      it "output if @level >= VERBOSE" do
        expect { display.quiet("Quiet message") }.to output(/Quiet message/).to_stdout
      end

      it "output nothing if @level < VERBOSE" do
        expect { display.debug("Debug?") }.not_to output.to_stdout
      end
    end

    describe "#debug(message = nil, color: false)" do
      let(:disp) { described_class.new(level: debug_lvl) }

      it "output all verbosity levels" do
        expect { display.quiet("Quiet message") }.to output(/Quiet message/).to_stdout
      end
    end
  end
end
