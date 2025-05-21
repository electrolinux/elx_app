# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"
require "rubocop/rake_task"

# Prevent pushing to RubyGems.org by overriding the gem push task
Rake::Task["release:rubygem_push"].clear
desc "Overrides the default release:rubygem_push task to prevent public gem releases"
task "release:rubygem_push" do
  puts "Skipping RubyGems push (private gem release)"
end

# Customize the release task to add your message
desc "Overrides the default release task to prevent public gem releases"
task :release do
  puts "Releasing gem version #{Haconfig::VERSION} to Git repository only..."
  Rake::Task["release"].invoke
  puts "Released version #{Haconfig::VERSION} to Git repository."
end

RSpec::Core::RakeTask.new(:spec) do |task|
  task.pattern = "spec/elx_app/**/*_spec.rb"
  task.verbose = false
end

RuboCop::RakeTask.new

Dir.glob("lib/haconfig/tasks/*.rake").each { |r| load r }

task default: %i[spec rubocop]
