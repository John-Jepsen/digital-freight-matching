# frozen_string_literal: true

require 'rails_helper'
require_relative '../lib/api_smoke_test_orchestrator'

RSpec.describe 'API Smoke Tests', type: :request do
  let(:orchestrator) { ApiSmokeTestFramework::SmokeTestOrchestrator.new }
  
  before(:all) do
    # Configure the smoke test framework for test environment
    ApiSmokeTestFramework.configure do |config|
      config.base_url = 'http://localhost:3001'
      config.environment = 'test'
      config.timeout = 30
      config.logger.level = Logger::WARN # Reduce noise in test output
    end
  end

  describe 'endpoint discovery' do
    it 'discovers all API endpoints' do
      endpoints = orchestrator.discover_endpoints
      
      expect(endpoints).to be_an(Array)
      expect(endpoints).not_to be_empty
      
      # Should include health check endpoints
      health_endpoints = endpoints.select { |ep| ep[:category] == :health_check }
      expect(health_endpoints).not_to be_empty
      
      # Should include authentication endpoints  
      auth_endpoints = endpoints.select { |ep| ep[:category] == :authentication }
      expect(auth_endpoints).not_to be_empty
      
      # Each endpoint should have required attributes
      endpoints.each do |endpoint|
        expect(endpoint).to have_key(:path)
        expect(endpoint).to have_key(:method)
        expect(endpoint).to have_key(:category)
        expect(endpoint[:path]).to start_with('/api/')
      end
    end

    it 'categorizes endpoints correctly' do
      endpoints = orchestrator.discover_endpoints
      
      # Check that we have different categories
      categories = endpoints.map { |ep| ep[:category] }.uniq
      expect(categories).to include(:health_check)
      expect(categories).to include(:authentication)
      
      # Health endpoints should be categorized correctly
      health_endpoints = endpoints.select { |ep| ep[:category] == :health_check }
      health_endpoints.each do |endpoint|
        expect(endpoint[:path]).to match(/health/)
      end

      # Auth endpoints should be categorized correctly
      auth_endpoints = endpoints.select { |ep| ep[:category] == :authentication }
      auth_endpoints.each do |endpoint|
        expect(endpoint[:path]).to match(/auth/)
      end
    end
  end

  describe 'health check tests' do
    it 'runs health check endpoint tests successfully' do
      orchestrator.discover_endpoints
      results = orchestrator.run_category_tests(:health_check)
      
      expect(results).to be_an(Array)
      expect(results).not_to be_empty
      
      # At least one health check should pass
      passed_tests = results.select { |r| r[:passed] }
      expect(passed_tests).not_to be_empty
      
      # Check that results have expected structure
      results.each do |result|
        expect(result).to have_key(:endpoint)
        expect(result).to have_key(:passed)
        expect(result).to have_key(:status)
        expect(result).to have_key(:response_time_ms)
        expect(result).to have_key(:timestamp)
      end
    end
  end

  describe 'authentication tests' do
    it 'runs authentication endpoint tests' do
      orchestrator.discover_endpoints
      results = orchestrator.run_category_tests(:authentication)
      
      expect(results).to be_an(Array)
      
      # Should test different auth endpoints
      endpoints_tested = results.map { |r| r[:endpoint][:action] }.uniq
      
      # Check structure of results
      results.each do |result|
        expect(result).to have_key(:endpoint)
        expect(result).to have_key(:passed)
        expect(result).to have_key(:timestamp)
        
        # Response time should be recorded
        expect(result[:response_time_ms]).to be_a(Numeric) if result[:response_time_ms]
      end
    end
  end

  describe 'comprehensive smoke test' do
    it 'runs all endpoint tests without crashing', :slow do
      orchestrator.discover_endpoints
      results = orchestrator.run_all_tests
      
      expect(results).to be_an(Array)
      expect(results).not_to be_empty
      
      # Should have tested multiple categories
      categories_tested = results.map { |r| r[:endpoint][:category] }.uniq
      expect(categories_tested.length).to be > 1
      
      # Should have some successful tests (at least health checks)
      passed_tests = results.select { |r| r[:passed] }
      expect(passed_tests).not_to be_empty
      
      # Check that test summary is generated
      summary = orchestrator.summary
      expect(summary).to have_key(:total_tests)
      expect(summary).to have_key(:passed_count)
      expect(summary).to have_key(:failed_count)
      expect(summary).to have_key(:success_rate)
      expect(summary).to have_key(:total_duration_ms)
      
      expect(summary[:total_tests]).to eq(results.length)
      expect(summary[:passed_count]).to eq(passed_tests.length)
      expect(summary[:failed_count]).to eq(results.length - passed_tests.length)
    end
  end

  describe 'test reporting' do
    before do
      orchestrator.discover_endpoints
      orchestrator.run_category_tests(:health_check)
    end

    it 'generates text report' do
      report = orchestrator.generate_report(format: :text)
      
      expect(report).to be_a(String)
      expect(report).to include('API SMOKE TEST RESULTS')
      expect(report).to include('Test Summary:')
      expect(report).to include('Total Tests:')
      expect(report).to include('Passed:')
      expect(report).to include('Failed:')
      expect(report).to include('Success Rate:')
    end

    it 'generates JSON report' do
      report = orchestrator.generate_report(format: :json)
      
      expect(report).to be_a(String)
      parsed_report = JSON.parse(report)
      
      expect(parsed_report).to have_key('summary')
      expect(parsed_report).to have_key('results')
      expect(parsed_report['summary']).to have_key('total_tests')
      expect(parsed_report['summary']).to have_key('success_rate')
      expect(parsed_report['results']).to be_an(Array)
    end

    it 'generates HTML report' do
      report = orchestrator.generate_report(format: :html)
      
      expect(report).to be_a(String)
      expect(report).to include('<!DOCTYPE html>')
      expect(report).to include('<title>API Smoke Test Results</title>')
      expect(report).to include('API Smoke Test Results')
      expect(report).to include('Summary')
    end
  end

  describe 'error handling' do
    it 'handles invalid endpoints gracefully' do
      # Test with a non-existent endpoint
      fake_endpoint = {
        path: '/api/v1/nonexistent',
        method: 'get',
        category: :custom_action,
        controller: 'nonexistent',
        action: 'index'
      }

      result = orchestrator.run_endpoint_test(fake_endpoint)
      
      expect(result).to have_key(:passed)
      expect(result[:passed]).to be false
      expect(result).to have_key(:status)
      
      # Should handle the error without crashing
      expect(result[:status]).to be_in([404, 0]) # 404 for not found, 0 for connection error
    end

    it 'handles timeout gracefully' do
      # Configure a very short timeout
      short_timeout_config = ApiSmokeTestFramework::Configuration.new
      short_timeout_config.timeout = 1
      short_timeout_config.base_url = 'http://httpbin.org/delay/5' # This will timeout
      short_timeout_config.logger.level = Logger::FATAL

      client = ApiSmokeTestFramework::HttpClient.new(short_timeout_config)
      
      response = client.make_request('GET', '/')
      
      expect(response[:success]).to be false
      expect(response).to have_key(:error)
    end
  end

  describe 'performance metrics' do
    it 'tracks response times' do
      orchestrator.discover_endpoints
      results = orchestrator.run_category_tests(:health_check)
      
      # All successful tests should have response times
      successful_results = results.select { |r| r[:passed] && r[:status] == 200 }
      successful_results.each do |result|
        expect(result[:response_time_ms]).to be_a(Numeric)
        expect(result[:response_time_ms]).to be > 0
      end
    end

    it 'identifies slowest and fastest endpoints' do
      orchestrator.discover_endpoints
      orchestrator.run_category_tests(:health_check)
      
      summary = orchestrator.summary
      
      if summary[:slowest_endpoint]
        expect(summary[:slowest_endpoint]).to have_key(:response_time_ms)
        expect(summary[:slowest_endpoint][:response_time_ms]).to be_a(Numeric)
      end

      if summary[:fastest_endpoint]
        expect(summary[:fastest_endpoint]).to have_key(:response_time_ms)
        expect(summary[:fastest_endpoint][:response_time_ms]).to be_a(Numeric)
      end
    end

    it 'calculates category statistics' do
      orchestrator.discover_endpoints
      orchestrator.run_all_tests
      
      summary = orchestrator.summary
      expect(summary).to have_key(:categories)
      
      summary[:categories].each do |category, stats|
        expect(stats).to have_key(:total)
        expect(stats).to have_key(:passed)
        expect(stats).to have_key(:failed)
        expect(stats).to have_key(:success_rate)
        
        expect(stats[:total]).to eq(stats[:passed] + stats[:failed])
        expect(stats[:success_rate]).to be_between(0, 100)
      end
    end
  end
end