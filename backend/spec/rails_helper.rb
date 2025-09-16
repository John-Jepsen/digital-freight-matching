# frozen_string_literal: true

# This file is copied to spec/ when you run 'rails generate rspec:install'
require 'spec_helper'
ENV['RAILS_ENV'] ||= 'test'

begin
  require_relative '../config/environment'
rescue LoadError => e
  # Rails environment not available, create a minimal setup
  puts "Rails environment not available: #{e.message}"
  puts "Running in standalone mode..."
end

# Prevent database truncation if the environment is production
if defined?(Rails) && Rails.env.production?
  abort("The Rails environment is running in production mode!")
end

require 'rspec/rails' if defined?(Rails)

# Add additional requires based on your test setup
# require 'factory_bot_rails' if defined?(FactoryBot)
# require 'shoulda/matchers' if defined?(Shoulda)

# Directory of fixtures
# fixture_path = Rails.root.join('spec/fixtures') if defined?(Rails)

# If you're not using ActiveRecord, or you'd prefer not to run each of your
# examples within a transaction, remove the following line or assign false
# instead of true.
# ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.create_unlogged_tables = true if defined?(ActiveRecord)

# RSpec Rails can automatically mix in different behaviours to your tests
# based on their file location, for example enabling you to call `get` and
# `post` in specs under `spec/controllers`.
#
# You can disable this behaviour by removing the line below, and instead
# explicitly tag your specs with their type, e.g.:
#
#     RSpec.describe UsersController, type: :controller do
#       # ...
#     end
#
# The different available types are documented in the features, such as in
# https://relishapp.com/rspec/rspec-rails/docs
if defined?(RSpec)
  RSpec.configure do |config|
    # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
    # config.fixture_path = fixture_path if fixture_path&.exist?

    # If you're not using ActiveRecord, or you'd prefer not to run each of your
    # examples within a transaction, remove the following line or assign false
    # instead of true.
    config.use_transactional_fixtures = false if defined?(ActiveRecord)

    # You can uncomment this line to turn off ActiveRecord support entirely.
    # config.use_active_record = false

    # RSpec Rails can automatically mix in different behaviours to your tests
    # based on their file location, for example enabling you to call `get` and
    # `post` in specs under `spec/controllers`.
    config.infer_spec_type_from_file_location!

    # Filter lines from Rails gems in backtraces.
    config.filter_rails_from_backtrace! if defined?(Rails)
    # arbitrary gems may also be filtered via:
    # config.filter_gems_from_backtrace("gem name")
    
    # Include smoke test helpers
    config.include_context "smoke test setup", type: :smoke_test
  end
end