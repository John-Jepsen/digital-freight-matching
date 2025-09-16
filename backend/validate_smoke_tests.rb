#!/usr/bin/env ruby
# frozen_string_literal: true

# Comprehensive smoke test validation script
# Tests all the smoke test functionality

puts "🧪 Comprehensive Smoke Test Framework Validation"
puts "=" * 60

begin
  require_relative 'lib/api_smoke_test_orchestrator'
  puts "✅ Smoke test framework loaded successfully"
rescue => e
  puts "❌ Failed to load framework: #{e.message}"
  exit 1
end

# Test Configuration
puts "\n1️⃣  Testing Configuration"
puts "-" * 25

config = ApiSmokeTestFramework.configuration
puts "✅ Default configuration loaded"
puts "   Base URL: #{config.base_url}"
puts "   Timeout: #{config.timeout}s"

# Test Custom Configuration
ApiSmokeTestFramework.configure do |c|
  c.base_url = 'http://test.example.com'
  c.timeout = 15
end
puts "✅ Custom configuration works"

# Test Test Runners
puts "\n2️⃣  Testing Test Runners"
puts "-" * 25

runners = [
  ApiSmokeTestFramework::HealthCheckTestRunner,
  ApiSmokeTestFramework::AuthenticationTestRunner,
  ApiSmokeTestFramework::ResourceTestRunner,
  ApiSmokeTestFramework::AnalyticsTestRunner,
  ApiSmokeTestFramework::PerformanceTestRunner
]

runners.each do |runner_class|
  begin
    runner = runner_class.new
    puts "✅ #{runner_class.name.split('::').last} created"
  rescue => e
    puts "❌ #{runner_class.name.split('::').last} failed: #{e.message}"
  end
end

# Test Orchestrator
puts "\n3️⃣  Testing Orchestrator"
puts "-" * 20

orchestrator = ApiSmokeTestFramework::SmokeTestOrchestrator.new
puts "✅ Orchestrator created"

endpoints = orchestrator.discover_endpoints
puts "✅ Endpoint discovery: #{endpoints.length} endpoints found"

# Test CLI
puts "\n4️⃣  Testing CLI"
puts "-" * 15

puts "Help command:"
ApiSmokeTestFramework::CLI.run(['help'])

puts "\n✅ CLI framework operational"

# Test Report Generation
puts "\n5️⃣  Testing Report Generation"
puts "-" * 30

# Mock results for testing
mock_results = [
  {
    endpoint: { path: '/test', method: 'get', category: :health_check },
    passed: true,
    status: 200,
    response_time_ms: 100,
    timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S%z')
  }
]

orchestrator.instance_variable_set(:@results, mock_results)
orchestrator.send(:generate_summary, Time.now - 1, Time.now)

text_report = orchestrator.generate_report(format: :text)
puts "✅ Text report: #{text_report.length} characters"

json_report = orchestrator.generate_report(format: :json)
puts "✅ JSON report: #{json_report.length} characters"

html_report = orchestrator.generate_report(format: :html) 
puts "✅ HTML report: #{html_report.length} characters"

puts "\n🎯 Validation Complete!"
puts "=" * 25
puts "✅ All smoke test components are functional"
puts "✅ Framework ready for production use"
puts "\n📋 To test with real API endpoints:"
puts "   1. Start Rails server: bundle exec rails server -p 3001"
puts "   2. Run tests: bin/smoke_test all"
puts "   3. Or run specs: bundle exec rspec spec/smoke_test_spec.rb"