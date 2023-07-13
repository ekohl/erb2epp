# frozen_string_literal: true

default_tasks = []

begin
  require 'voxpupuli/rubocop/rake'
rescue LoadError
  # rubocop bundler group not enabled
else
  default_tasks << :rubocop
end

begin
  require 'rspec/core/rake_task'
rescue LoadError
  # test group not enabled
else
  RSpec::Core::RakeTask.new
  default_tasks << :spec
end

task default: default_tasks if default_tasks.any?
