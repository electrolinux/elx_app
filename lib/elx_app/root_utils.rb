# frozen_string_literal: true

require "rainbow"

module ElxApp
  ##
  # Our RootUtils module
  #
  module RootUtils
    ##
    # Helper to enforce app to be run as root
    #
    module ClassMethods
      def ensure_root_app(options: nil, logger: nil, config: nil)
        return new(options: options, logger: logger, config: config) if Process.uid.zero?

        puts Rainbow("Reloading application with sudo...").orangered
        via_bundle = $PROGRAM_NAME.match?(%r{^(exe|bin)/})
        be = via_bundle ? "bundle exec" : ""
        cmdline = "sudo #{be} #{$PROGRAM_NAME} #{ARGV.join(" ")}"
        exec(cmdline)
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end
  end
end
