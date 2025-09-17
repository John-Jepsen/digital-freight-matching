# frozen_string_literal: true

require_relative '../lib/api_smoke_test_orchestrator'

namespace :smoke_test do
  desc "Run all API smoke tests"
  task all: :environment do
    puts "🔥 Running API Smoke Tests"
    puts "=" * 50
    
    orchestrator = ApiSmokeTestFramework::SmokeTestOrchestrator.new
    orchestrator.discover_endpoints
    orchestrator.run_all_tests
    
    puts orchestrator.generate_report(format: :text)
    
    # Exit with error code if tests failed
    summary = orchestrator.summary
    exit(1) if summary[:failed_count] > 0
  end

  desc "Run smoke tests for a specific category"
  task :category, [:category_name] => :environment do |_task, args|
    category = args[:category_name]&.to_sym
    
    unless category
      puts "Usage: rake smoke_test:category[category_name]"
      puts "Available categories: health_check, authentication, list_resource, get_resource, create_resource, update_resource, delete_resource, custom_action"
      exit(1)
    end

    puts "🔥 Running #{category.to_s.titleize} Smoke Tests"
    puts "=" * 50
    
    orchestrator = ApiSmokeTestFramework::SmokeTestOrchestrator.new
    orchestrator.discover_endpoints
    results = orchestrator.run_category_tests(category)
    
    if results.empty?
      puts "No endpoints found for category: #{category}"
      exit(1)
    end
    
    puts "\nResults for #{category.to_s.titleize}:"
    puts "-" * 40
    
    results.each do |result|
      endpoint = result[:endpoint]
      status_icon = result[:passed] ? "✓" : "✗"
      puts "#{status_icon} #{endpoint[:method].upcase} #{endpoint[:path]} - #{result[:status]} (#{result[:response_time_ms]}ms)"
    end
    
    passed_count = results.count { |r| r[:passed] }
    failed_count = results.length - passed_count
    success_rate = results.empty? ? 0 : (passed_count.to_f / results.length * 100).round(2)
    
    puts "\nSummary: #{passed_count} passed, #{failed_count} failed (#{success_rate}% success rate)"
    
    exit(1) if failed_count > 0
  end

  desc "Discover all API endpoints"
  task discover: :environment do
    puts "🔍 Discovering API Endpoints"
    puts "=" * 30
    
    orchestrator = ApiSmokeTestFramework::SmokeTestOrchestrator.new
    endpoints = orchestrator.discover_endpoints
    
    endpoints.group_by { |ep| ep[:category] }.each do |category, eps|
      puts "\n#{category.to_s.titleize} (#{eps.length}):"
      eps.each do |ep|
        puts "  #{ep[:method].upcase.ljust(6)} #{ep[:path]}"
      end
    end
    
    puts "\nTotal: #{endpoints.length} endpoints discovered"
  end

  desc "Run health check tests only"
  task health: :environment do
    Rake::Task['smoke_test:category'].invoke('health_check')
  end

  desc "Run authentication tests only"
  task auth: :environment do
    Rake::Task['smoke_test:category'].invoke('authentication')
  end

  desc "Run analytics tests only"
  task analytics: :environment do
    Rake::Task['smoke_test:category'].invoke('analytics')
  end

  desc "Run performance tests"
  task performance: :environment do
    puts "🚀 Running Performance Tests"
    puts "=" * 30
    
    orchestrator = ApiSmokeTestFramework::SmokeTestOrchestrator.new
    orchestrator.discover_endpoints
    results = orchestrator.run_category_tests(:performance)
    
    if results.empty?
      puts "No dedicated performance endpoints found. Testing health endpoints for performance..."
      # Test health endpoints with performance runner
      health_endpoints = orchestrator.instance_variable_get(:@endpoints).select { |ep| ep[:category] == :health_check }
      
      performance_runner = ApiSmokeTestFramework::PerformanceTestRunner.new
      results = health_endpoints.map do |endpoint|
        performance_runner.run_test(endpoint, { iterations: 5 })
      end
    end
    
    puts "\nPerformance Results:"
    puts "-" * 25
    
    results.each do |result|
      endpoint = result[:endpoint]
      puts "#{endpoint[:method].upcase} #{endpoint[:path]}"
      puts "  Avg Response: #{result[:response_time_ms]}ms"
      puts "  Success Rate: #{result[:success_rate] || 'N/A'}%"
      if result[:min_response_time] && result[:max_response_time]
        puts "  Range: #{result[:min_response_time]}ms - #{result[:max_response_time]}ms"
      end
      puts ""
    end
  end

  desc "Generate HTML report for the last test run"
  task :report, [:format] => :environment do |_task, args|
    format = (args[:format] || 'html').to_sym
    
    unless [:text, :json, :html].include?(format)
      puts "Invalid format. Use: text, json, or html"
      exit(1)
    end
    
    puts "🔥 Running tests and generating #{format.upcase} report..."
    
    orchestrator = ApiSmokeTestFramework::SmokeTestOrchestrator.new
    orchestrator.discover_endpoints
    orchestrator.run_all_tests
    
    report = orchestrator.generate_report(format: format)
    
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    filename = "smoke_test_report_#{timestamp}.#{format}"
    
    File.write(filename, report)
    puts "Report saved to: #{filename}"
    
    if format == :html
      puts "Open in browser: file://#{File.absolute_path(filename)}"
    end
  end

  desc "Run smoke tests with custom configuration"
  task :custom, [:base_url, :timeout] => :environment do |_task, args|
    base_url = args[:base_url] || 'http://localhost:3001'
    timeout = (args[:timeout] || '30').to_i
    
    puts "🔥 Running Custom Smoke Tests"
    puts "Base URL: #{base_url}"
    puts "Timeout: #{timeout}s"
    puts "=" * 50
    
    ApiSmokeTestFramework.configure do |config|
      config.base_url = base_url
      config.timeout = timeout
    end
    
    orchestrator = ApiSmokeTestFramework::SmokeTestOrchestrator.new
    orchestrator.discover_endpoints
    orchestrator.run_all_tests
    
    puts orchestrator.generate_report(format: :text)
  end

  desc "Validate API stub responses for schema compliance"
  task validate: :environment do
    puts "🔥 Validating API Response Schemas"
    puts "=" * 40
    
    orchestrator = ApiSmokeTestFramework::SmokeTestOrchestrator.new
    orchestrator.discover_endpoints
    
    # Run health checks first to ensure basic connectivity
    health_results = orchestrator.run_category_tests(:health_check)
    health_passed = health_results.count { |r| r[:passed] }
    
    if health_passed == 0
      puts "❌ Health checks failed. Cannot proceed with validation."
      exit(1)
    end
    
    puts "✅ Health checks passed (#{health_passed}/#{health_results.length})"
    
    # Run a subset of tests to validate response schemas
    categories_to_validate = [:authentication, :list_resource, :get_resource]
    validation_results = []
    
    categories_to_validate.each do |category|
      results = orchestrator.run_category_tests(category)
      validation_results.concat(results)
      
      passed = results.count { |r| r[:passed] }
      puts "#{category.to_s.titleize}: #{passed}/#{results.length} passed"
    end
    
    total_passed = validation_results.count { |r| r[:passed] }
    total_tests = validation_results.length
    success_rate = total_tests.zero? ? 0 : (total_passed.to_f / total_tests * 100).round(2)
    
    puts "\nOverall Validation: #{total_passed}/#{total_tests} passed (#{success_rate}%)"
    
    if success_rate < 80
      puts "❌ Validation failed - success rate below 80%"
      exit(1)
    else
      puts "✅ Validation passed"
    end
  end
end

# Alias for convenience
desc "Run all API smoke tests (alias for smoke_test:all)"
task smoke_test: 'smoke_test:all'