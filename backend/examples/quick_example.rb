#!/usr/bin/env ruby
# frozen_string_literal: true

# Quick example showing how to use the API Smoke Testing Framework
# This script demonstrates basic usage patterns

puts "🚚 Digital Freight Matching - API Smoke Test Quick Example"
puts "=" * 60

# Add lib directory to load path
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require_relative '../lib/api_smoke_test_orchestrator'

# Configure for your environment
ApiSmokeTestFramework.configure do |config|
  config.base_url = ENV.fetch('API_BASE_URL', 'http://localhost:3001')
  config.timeout = 15
  config.logger.level = Logger::INFO
end

puts "Configuration:"
puts "  Base URL: #{ApiSmokeTestFramework.configuration.base_url}"
puts "  Timeout: #{ApiSmokeTestFramework.configuration.timeout}s"
puts ""

# Create orchestrator
orchestrator = ApiSmokeTestFramework::SmokeTestOrchestrator.new

# Example 1: Discover endpoints
puts "1️⃣  Endpoint Discovery"
puts "-" * 25

if defined?(Rails)
  endpoints = orchestrator.discover_endpoints
  puts "Discovered #{endpoints.length} API endpoints"
  
  # Show categories
  categories = endpoints.group_by { |ep| ep[:category] }
  categories.each do |category, eps|
    puts "  #{category}: #{eps.length} endpoints"
  end
else
  puts "Rails not available - endpoint discovery limited"
  
  # Create some example endpoints for demonstration
  endpoints = [
    {
      path: '/api/v1/health',
      method: 'get',
      category: :health_check,
      controller: 'api/v1/health',
      action: 'show'
    },
    {
      path: '/api/v1/auth/login',
      method: 'post',
      category: :authentication,
      controller: 'api/v1/auth',
      action: 'login'
    }
  ]
  
  # Manually set endpoints for demo
  orchestrator.instance_variable_set(:@endpoints, endpoints)
  puts "Using #{endpoints.length} demo endpoints"
end

puts ""

# Example 2: Test health checks only
puts "2️⃣  Health Check Tests"
puts "-" * 25

health_results = orchestrator.run_category_tests(:health_check)
if health_results.any?
  passed = health_results.count { |r| r[:passed] }
  puts "Health check results: #{passed}/#{health_results.length} passed"
  
  health_results.each do |result|
    endpoint = result[:endpoint]
    icon = result[:passed] ? "✅" : "❌"
    puts "  #{icon} #{endpoint[:method].upcase} #{endpoint[:path]} - #{result[:status]}"
  end
else
  puts "No health check endpoints found or server not running"
  puts "💡 Try starting the Rails server: rails server -p 3001"
end

puts ""

# Example 3: Generate a simple report
puts "3️⃣  Report Generation"
puts "-" * 25

if health_results.any?
  text_report = orchestrator.generate_report(format: :text)
  
  # Show first few lines of the report
  report_lines = text_report.split("\n")
  summary_lines = report_lines.take(15)
  
  puts summary_lines.join("\n")
  
  if report_lines.length > 15
    puts "... (truncated, #{report_lines.length - 15} more lines)"
  end
else
  puts "No test results to generate report from"
end

puts ""

# Example 4: Show available commands
puts "4️⃣  Available Commands"
puts "-" * 25

puts "Rake tasks:"
puts "  rake smoke_test:all              # Run all tests"
puts "  rake smoke_test:health           # Run health checks"
puts "  rake smoke_test:discover         # Discover endpoints"
puts "  rake smoke_test:report[html]     # Generate HTML report"
puts ""

puts "CLI commands:"
puts "  ./bin/smoke_test all             # Run all tests"
puts "  ./bin/smoke_test category health_check"
puts "  ./bin/smoke_test discover        # List all endpoints"
puts ""

puts "RSpec integration:"
puts "  bundle exec rspec spec/smoke_test_spec.rb"
puts ""

# Example 5: Tips for getting started
puts "5️⃣  Getting Started Tips"
puts "-" * 25

if defined?(Rails)
  puts "✅ Rails environment detected"
  
  # Check if server is likely running
  require 'net/http'
  begin
    uri = URI(ApiSmokeTestFramework.configuration.base_url)
    response = Net::HTTP.get_response(uri)
    puts "✅ API server appears to be running (#{response.code})"
  rescue => e
    puts "❌ API server not responding: #{e.message}"
    puts "   Start server: rails server -p 3001"
  end
else
  puts "❌ Rails environment not loaded"
  puts "   Try: cd backend && bundle exec ruby examples/quick_example.rb"
end

puts ""
puts "Configuration options:"
puts "  SMOKE_TEST_BASE_URL=http://localhost:3001"
puts "  SMOKE_TEST_TIMEOUT=30"
puts "  RAILS_ENV=test"
puts ""

puts "📚 For complete documentation, see:"
puts "  docs/api-smoke-testing-framework.md"
puts ""

puts "🎉 Happy testing!"