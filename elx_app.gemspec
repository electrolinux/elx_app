# frozen_string_literal: true

require_relative "lib/elx_app/version"

Gem::Specification.new do |spec|
  spec.name = "elx_app"
  spec.version = ElxApp::VERSION
  spec.authors = ["Didier Belot"]
  spec.email = ["electrolinux@gmail.com"]

  spec.summary = "A simple gem to create a CLI application tailored to my needs."
  # spec.description = "TODO: Write a longer description or delete this line."
  # spec.homepage = "TODO: Put your gem's website or public repo URL here."
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  # spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  # spec.metadata["homepage_uri"] = spec.homepage
  # spec.metadata["source_code_uri"] = "TODO: Put your gem's public repo URL here."
  # spec.metadata["changelog_uri"] = "TODO: Put your gem's CHANGELOG.md URL here."

  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "dotenv", "~> 3.1.8"
  spec.add_dependency "mustache", "~> 1.1"
  spec.add_dependency "rainbow", "~> 3.1.1"
  spec.add_dependency "wisper", "~> 2.0"
end
