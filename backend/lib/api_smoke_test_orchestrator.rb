# frozen_string_literal: true

require_relative 'api_smoke_test_framework'
require_relative 'api_smoke_test_runners'

module ApiSmokeTestFramework
  # Main orchestrator for running smoke tests
  class SmokeTestOrchestrator
    attr_reader :config, :results, :summary

    def initialize(config = ApiSmokeTestFramework.configuration)
      @config = config
      @endpoints = []
      @runners = {}
      @results = []
      @summary = {}
      setup_runners
    end

    def discover_endpoints
      @endpoints = EndpointDiscovery.discover_endpoints
      @config.logger.info "Discovered #{@endpoints.length} API endpoints"
      @endpoints
    end

    def run_all_tests(options = {})
      @config.logger.info "Starting smoke tests for #{@endpoints.length} endpoints"
      start_time = Time.now

      @endpoints.each do |endpoint|
        run_endpoint_test(endpoint, options)
      end

      end_time = Time.now
      generate_summary(start_time, end_time)
      
      @config.logger.info "Smoke tests completed in #{@summary[:total_duration_ms]}ms"
      @config.logger.info "Results: #{@summary[:passed_count]} passed, #{@summary[:failed_count]} failed"
      
      @results
    end

    def run_category_tests(category, options = {})
      category_endpoints = @endpoints.select { |ep| ep[:category] == category }
      @config.logger.info "Running tests for #{category} endpoints (#{category_endpoints.length} endpoints)"
      
      start_time = Time.now
      
      category_endpoints.each do |endpoint|
        run_endpoint_test(endpoint, options)
      end

      end_time = Time.now
      duration = ((end_time - start_time) * 1000).round(2)
      
      # Generate summary for this category
      category_results = @results.select { |r| r[:endpoint][:category] == category }
      generate_summary(start_time, end_time) if @summary.empty?
      
      @config.logger.info "Category #{category} tests completed in #{duration}ms"
      
      category_results
    end

    def run_endpoint_test(endpoint, options = {})
      runner = get_runner_for_endpoint(endpoint)
      return nil unless runner

      begin
        result = runner.run_test(endpoint, options)
        @results << result
        result
      rescue => e
        @config.logger.error "Failed to run test for #{endpoint[:method]} #{endpoint[:path]}: #{e.message}"
        error_result = {
          endpoint: endpoint,
          success: false,
          error: e.message,
          passed: false,
          timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S%z')
        }
        @results << error_result
        error_result
      end
    end

    def get_test_results
      @results
    end

    def generate_report(format: :text)
      case format
      when :text
        generate_text_report
      when :json
        generate_json_report
      when :html
        generate_html_report
      else
        raise ArgumentError, "Unsupported report format: #{format}"
      end
    end

    private

    def setup_runners
      @runners[:health_check] = HealthCheckTestRunner.new(@config)
      @runners[:authentication] = AuthenticationTestRunner.new(@config)
      @runners[:default] = ResourceTestRunner.new(@config)
    end

    def get_runner_for_endpoint(endpoint)
      case endpoint[:category]
      when :health_check
        @runners[:health_check]
      when :authentication
        @runners[:authentication]
      else
        @runners[:default]
      end
    end

    def generate_summary(start_time, end_time)
      total_duration = ((end_time - start_time) * 1000).round(2)
      passed_results = @results.select { |r| r[:passed] }
      failed_results = @results.reject { |r| r[:passed] }

      @summary = {
        total_tests: @results.length,
        passed_count: passed_results.length,
        failed_count: failed_results.length,
        success_rate: @results.empty? ? 0 : (passed_results.length.to_f / @results.length * 100).round(2),
        total_duration_ms: total_duration,
        average_response_time_ms: calculate_average_response_time,
        slowest_endpoint: find_slowest_endpoint,
        fastest_endpoint: find_fastest_endpoint,
        categories: generate_category_summary,
        timestamp: start_time.strftime('%Y-%m-%dT%H:%M:%S%z')
      }
    end

    def calculate_average_response_time
      response_times = @results.filter_map { |r| r[:response_time_ms] }
      return 0 if response_times.empty?
      
      (response_times.sum / response_times.length).round(2)
    end

    def find_slowest_endpoint
      @results.max_by { |r| r[:response_time_ms] || 0 }
    end

    def find_fastest_endpoint
      @results.select { |r| r[:response_time_ms] && r[:response_time_ms] > 0 }
              .min_by { |r| r[:response_time_ms] }
    end

    def generate_category_summary
      summary = {}
      
      @results.group_by { |r| r[:endpoint][:category] }.each do |category, results|
        passed = results.count { |r| r[:passed] }
        total = results.length
        
        summary[category] = {
          total: total,
          passed: passed,
          failed: total - passed,
          success_rate: total.zero? ? 0 : (passed.to_f / total * 100).round(2)
        }
      end
      
      summary
    end

    def generate_text_report
      report = []
      report << "=" * 60
      report << "API SMOKE TEST RESULTS"
      report << "=" * 60
      report << ""
      report << "Test Summary:"
      report << "  Total Tests: #{@summary[:total_tests]}"
      report << "  Passed: #{@summary[:passed_count]}"
      report << "  Failed: #{@summary[:failed_count]}"
      report << "  Success Rate: #{@summary[:success_rate]}%"
      report << "  Total Duration: #{@summary[:total_duration_ms]}ms"
      report << "  Average Response Time: #{@summary[:average_response_time_ms]}ms"
      report << ""

      if @summary[:categories]&.any?
        report << "Results by Category:"
        @summary[:categories].each do |category, stats|
          category_name = category.to_s.split('_').map(&:capitalize).join(' ')
          report << "  #{category_name}:"
          report << "    Total: #{stats[:total]}, Passed: #{stats[:passed]}, Failed: #{stats[:failed]} (#{stats[:success_rate]}%)"
        end
        report << ""
      end

      if @summary[:slowest_endpoint]
        slowest = @summary[:slowest_endpoint]
        report << "Slowest Endpoint:"
        report << "  #{slowest[:endpoint][:method].upcase} #{slowest[:endpoint][:path]} - #{slowest[:response_time_ms]}ms"
        report << ""
      end

      failed_tests = @results.reject { |r| r[:passed] }
      if failed_tests.any?
        report << "Failed Tests:"
        failed_tests.each do |result|
          endpoint = result[:endpoint]
          report << "  [FAIL] #{endpoint[:method].upcase} #{endpoint[:path]}"
          report << "         Status: #{result[:status]} | Error: #{result[:error]}" if result[:error]
        end
        report << ""
      end

      report << "Detailed Results:"
      @results.each do |result|
        endpoint = result[:endpoint]
        status_icon = result[:passed] ? "✓" : "✗"
        report << "  #{status_icon} #{endpoint[:method].upcase} #{endpoint[:path]} - #{result[:status]} (#{result[:response_time_ms]}ms)"
      end

      report.join("\n")
    end

    def generate_json_report
      {
        summary: @summary,
        results: @results.map do |result|
          {
            endpoint: result[:endpoint],
            passed: result[:passed],
            status: result[:status],
            response_time_ms: result[:response_time_ms],
            error: result[:error],
            timestamp: result[:timestamp]
          }
        end
      }.to_json
    end

    def generate_html_report
      # Basic HTML report template
      html = <<~HTML
        <!DOCTYPE html>
        <html>
        <head>
          <title>API Smoke Test Results</title>
          <style>
            body { font-family: Arial, sans-serif; margin: 20px; }
            .header { background: #f0f0f0; padding: 20px; border-radius: 5px; }
            .summary { margin: 20px 0; }
            .category { margin: 10px 0; }
            .test-result { padding: 5px; margin: 2px 0; border-radius: 3px; }
            .passed { background: #d4edda; color: #155724; }
            .failed { background: #f8d7da; color: #721c24; }
            .stats { display: inline-block; margin-right: 20px; }
          </style>
        </head>
        <body>
          <div class="header">
            <h1>API Smoke Test Results</h1>
            <p>Generated on #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}</p>
          </div>
          
          <div class="summary">
            <h2>Summary</h2>
            <div class="stats">Total: #{@summary[:total_tests]}</div>
            <div class="stats">Passed: #{@summary[:passed_count]}</div>
            <div class="stats">Failed: #{@summary[:failed_count]}</div>
            <div class="stats">Success Rate: #{@summary[:success_rate]}%</div>
            <div class="stats">Duration: #{@summary[:total_duration_ms]}ms</div>
          </div>

          <div class="categories">
            <h2>Results by Category</h2>
            #{generate_category_html}
          </div>

          <div class="results">
            <h2>Detailed Results</h2>
            #{generate_results_html}
          </div>
        </body>
        </html>
      HTML

      html
    end

    def generate_category_html
      return "" unless @summary[:categories]

      @summary[:categories].map do |category, stats|
        category_name = category.to_s.split('_').map(&:capitalize).join(' ')
        <<~HTML
          <div class="category">
            <strong>#{category_name}:</strong>
            Total: #{stats[:total]}, 
            Passed: #{stats[:passed]}, 
            Failed: #{stats[:failed]} 
            (#{stats[:success_rate]}%)
          </div>
        HTML
      end.join
    end

    def generate_results_html
      @results.map do |result|
        endpoint = result[:endpoint]
        css_class = result[:passed] ? "passed" : "failed"
        status_icon = result[:passed] ? "✓" : "✗"
        
        error_info = result[:error] ? " | Error: #{result[:error]}" : ""
        
        <<~HTML
          <div class="test-result #{css_class}">
            #{status_icon} #{endpoint[:method].upcase} #{endpoint[:path]} - 
            #{result[:status]} (#{result[:response_time_ms]}ms)#{error_info}
          </div>
        HTML
      end.join
    end
  end

  # CLI interface for running smoke tests
  class CLI
    def self.run(args = ARGV)
      command = args[0] || 'all'
      
      case command
      when 'all'
        run_all_tests(args[1..-1])
      when 'category'
        category = args[1]&.to_sym
        if category
          run_category_tests(category, args[2..-1])
        else
          puts "Usage: smoke_test category <category_name>"
          puts "Available categories: health_check, authentication, list_resource, get_resource, create_resource, update_resource, delete_resource, custom_action"
        end
      when 'discover'
        discover_endpoints
      when 'help', '--help', '-h'
        show_help
      else
        puts "Unknown command: #{command}"
        show_help
      end
    end

    private

    def self.run_all_tests(options)
      orchestrator = SmokeTestOrchestrator.new
      orchestrator.discover_endpoints
      orchestrator.run_all_tests
      
      puts orchestrator.generate_report(format: :text)
    end

    def self.run_category_tests(category, options)
      orchestrator = SmokeTestOrchestrator.new
      orchestrator.discover_endpoints
      results = orchestrator.run_category_tests(category)
      
      puts "Category: #{category}"
      puts "Results: #{results.count { |r| r[:passed] }} passed, #{results.count { |r| !r[:passed] }} failed"
      
      results.each do |result|
        endpoint = result[:endpoint]
        status = result[:passed] ? "PASS" : "FAIL"
        puts "  [#{status}] #{endpoint[:method].upcase} #{endpoint[:path]} - #{result[:status]}"
      end
    end

    def self.discover_endpoints
      orchestrator = SmokeTestOrchestrator.new
      endpoints = orchestrator.discover_endpoints
      
      puts "Discovered #{endpoints.length} API endpoints:"
      endpoints.group_by { |ep| ep[:category] }.each do |category, eps|
        category_name = category.to_s.split('_').map(&:capitalize).join(' ')
        puts "\n#{category_name} (#{eps.length}):"
        eps.each do |ep|
          puts "  #{ep[:method].upcase} #{ep[:path]}"
        end
      end
    end

    def self.show_help
      puts <<~HELP
        API Smoke Test Framework
        
        Usage:
          smoke_test [command] [options]
        
        Commands:
          all                   Run all smoke tests
          category <name>       Run tests for specific category
          discover             Discover all API endpoints
          help                 Show this help message
        
        Categories:
          health_check         Health check endpoints
          authentication       Auth endpoints (login, register, etc.)
          list_resource        GET /resource (index)
          get_resource         GET /resource/:id (show)
          create_resource      POST /resource (create)
          update_resource      PUT/PATCH /resource/:id (update)
          delete_resource      DELETE /resource/:id (destroy)
          custom_action        Custom endpoint actions
        
        Environment Variables:
          SMOKE_TEST_BASE_URL  Base URL for API (default: http://localhost:3001)
          SMOKE_TEST_TIMEOUT   Request timeout in seconds (default: 30)
          RAILS_ENV           Environment (default: test)
        
        Examples:
          smoke_test all
          smoke_test category health_check
          smoke_test discover
      HELP
    end
  end
end