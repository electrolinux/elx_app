# frozen_string_literal: true

require "bundler/setup"
require "dotenv"
require "elx_app"
require 'simplecov'

Dotenv.load("spec/support/.env.test")

SimpleCov.start do
  add_filter '/spec/' # Ignore les fichiers de test
  minimum_coverage 90 # Cible 90 % de couverture
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
end
