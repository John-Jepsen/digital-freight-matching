# frozen_string_literal: true

require_relative 'api_smoke_test_framework'

module ApiSmokeTestFramework
  # Authentication manager for handling tokens and credentials
  class AuthenticationManager
    def initialize(http_client)
      @http_client = http_client
      @tokens = {}
    end

    def authenticate_user(credentials = {})
      # Try to get auth token for API testing
      default_credentials = {
        email: 'test@example.com',
        password: 'password123'
      }
      
      auth_data = credentials.merge(default_credentials)
      
      response = @http_client.make_request('POST', '/api/v1/auth/login', {
        body: auth_data.to_json
      })

      if response[:success] && response[:body].is_a?(Hash)
        token = response[:body]['token'] || response[:body]['access_token']
        @tokens[:user] = token if token
      end

      response
    end

    def get_token(type = :user)
      @tokens[type]
    end

    def authenticated_request_options(type = :user)
      token = get_token(type)
      token ? { auth_token: token } : {}
    end
  end

  # Base test runner with common functionality
  class BaseTestRunner
    attr_reader :results, :config

    def initialize(config = ApiSmokeTestFramework.configuration)
      @config = config
      @http_client = HttpClient.new(config)
      @auth_manager = AuthenticationManager.new(@http_client)
      @results = []
    end

    def run_test(endpoint, options = {})
      start_time = Time.now
      
      test_result = {
        endpoint: endpoint,
        timestamp: start_time.strftime('%Y-%m-%dT%H:%M:%S%z'),
        options: options
      }

      begin
        response = execute_test(endpoint, options)
        test_result.merge!(response)
        test_result[:passed] = evaluate_response(response, endpoint)
      rescue => e
        test_result.merge!({
          success: false,
          error: e.message,
          passed: false
        })
      end

      test_result[:duration_ms] = ((Time.now - start_time) * 1000).round(2)
      @results << test_result
      log_result(test_result)
      test_result
    end

    protected

    def execute_test(endpoint, options)
      # Override in subclasses
      raise NotImplementedError
    end

    def evaluate_response(response, endpoint)
      # Override in subclasses for custom validation
      response[:success]
    end

    def log_result(result)
      status = result[:passed] ? "PASS" : "FAIL"
      method = result[:endpoint][:method].upcase
      path = result[:endpoint][:path]
      
      @config.logger.info "[#{status}] #{method} #{path} - #{result[:status]} (#{result[:response_time_ms]}ms)"
      
      if result[:error]
        @config.logger.error "  Error: #{result[:error]}"
      end
    end
  end

  # Health check test runner
  class HealthCheckTestRunner < BaseTestRunner
    def execute_test(endpoint, options)
      @http_client.make_request(endpoint[:method], endpoint[:path], options)
    end

    def evaluate_response(response, endpoint)
      return false unless response[:success]
      return false unless response[:status] == 200
      
      # Health checks should return JSON with status
      if response[:body].is_a?(Hash)
        status_indicators = %w[status state health]
        return status_indicators.any? { |key| response[:body].key?(key) }
      end
      
      true
    end
  end

  # Authentication test runner
  class AuthenticationTestRunner < BaseTestRunner
    def execute_test(endpoint, options)
      # Handle different auth endpoints differently
      case endpoint[:action]
      when 'login'
        test_login_endpoint(endpoint, options)
      when 'register'
        test_register_endpoint(endpoint, options)
      when 'logout'
        test_logout_endpoint(endpoint, options)
      when 'me', 'profile'
        test_protected_endpoint(endpoint, options)
      else
        test_auth_endpoint(endpoint, options)
      end
    end

    private

    def test_login_endpoint(endpoint, options)
      # Test with invalid credentials first
      response = @http_client.make_request(endpoint[:method], endpoint[:path], {
        body: { email: 'invalid@test.com', password: 'wrong' }.to_json
      })
      
      # Should return 401 for invalid credentials
      if response[:status] != 401
        @config.logger.warn "Login endpoint should return 401 for invalid credentials, got #{response[:status]}"
      end

      # Try actual authentication
      @auth_manager.authenticate_user
    end

    def test_register_endpoint(endpoint, options)
      unique_email = "test_#{Time.now.to_i}@example.com"
      @http_client.make_request(endpoint[:method], endpoint[:path], {
        body: {
          user: {
            email: unique_email,
            password: 'password123',
            password_confirmation: 'password123',
            first_name: 'Test',
            last_name: 'User'
          }
        }.to_json
      })
    end

    def test_logout_endpoint(endpoint, options)
      # Need authentication token for logout
      auth_options = @auth_manager.authenticated_request_options
      @http_client.make_request(endpoint[:method], endpoint[:path], auth_options)
    end

    def test_protected_endpoint(endpoint, options)
      # Test without auth token first
      response = @http_client.make_request(endpoint[:method], endpoint[:path])
      
      if response[:status] != 401
        @config.logger.warn "Protected endpoint should return 401 without auth, got #{response[:status]}"
      end

      # Test with auth token
      auth_options = @auth_manager.authenticated_request_options
      @http_client.make_request(endpoint[:method], endpoint[:path], auth_options)
    end

    def test_auth_endpoint(endpoint, options)
      @http_client.make_request(endpoint[:method], endpoint[:path], options)
    end

    def evaluate_response(response, endpoint)
      case endpoint[:action]
      when 'login'
        # Login should return token on success
        response[:success] && response[:body].is_a?(Hash) && 
        (response[:body].key?('token') || response[:body].key?('access_token'))
      when 'register'
        # Registration should return 201 or 200
        [200, 201].include?(response[:status])
      when 'logout'
        # Logout should return 200
        response[:status] == 200
      when 'me', 'profile'
        # Profile endpoints should return user data
        response[:success] && response[:body].is_a?(Hash)
      else
        response[:success]
      end
    end
  end

  # Resource test runner for CRUD operations
  class ResourceTestRunner < BaseTestRunner
    def execute_test(endpoint, options)
      case endpoint[:category]
      when :list_resource
        test_list_endpoint(endpoint, options)
      when :get_resource
        test_get_endpoint(endpoint, options)
      when :create_resource
        test_create_endpoint(endpoint, options)
      when :update_resource
        test_update_endpoint(endpoint, options)
      when :delete_resource
        test_delete_endpoint(endpoint, options)
      else
        test_custom_endpoint(endpoint, options)
      end
    end

    private

    def test_list_endpoint(endpoint, options)
      auth_options = @auth_manager.authenticated_request_options
      @http_client.make_request(endpoint[:method], endpoint[:path], auth_options.merge(options))
    end

    def test_get_endpoint(endpoint, options)
      # For show endpoints, we need an ID - use 1 as a test
      path = endpoint[:path].gsub(':id', '1')
      auth_options = @auth_manager.authenticated_request_options
      @http_client.make_request(endpoint[:method], path, auth_options.merge(options))
    end

    def test_create_endpoint(endpoint, options)
      # Create test data based on resource type
      test_data = generate_test_data(endpoint[:controller])
      auth_options = @auth_manager.authenticated_request_options
      
      @http_client.make_request(endpoint[:method], endpoint[:path], 
        auth_options.merge(body: test_data.to_json).merge(options))
    end

    def test_update_endpoint(endpoint, options)
      # For update endpoints, we need an ID
      path = endpoint[:path].gsub(':id', '1')
      test_data = generate_test_data(endpoint[:controller], update: true)
      auth_options = @auth_manager.authenticated_request_options
      
      @http_client.make_request(endpoint[:method], path, 
        auth_options.merge(body: test_data.to_json).merge(options))
    end

    def test_delete_endpoint(endpoint, options)
      # For delete endpoints, we need an ID
      path = endpoint[:path].gsub(':id', '1')
      auth_options = @auth_manager.authenticated_request_options
      @http_client.make_request(endpoint[:method], path, auth_options.merge(options))
    end

    def test_custom_endpoint(endpoint, options)
      auth_options = @auth_manager.authenticated_request_options
      @http_client.make_request(endpoint[:method], endpoint[:path], auth_options.merge(options))
    end

    def generate_test_data(controller, update: false)
      case controller
      when 'api/v1/loads'
        {
          load: {
            pickup_location: "Dallas, TX",
            delivery_location: "Austin, TX",
            pickup_datetime: (Time.now + (2 * 24 * 60 * 60)).strftime('%Y-%m-%dT%H:%M:%S%z'),
            delivery_datetime: (Time.now + (5 * 24 * 60 * 60)).strftime('%Y-%m-%dT%H:%M:%S%z'),
            weight: 1000,
            price: 500,
            description: "Test load for smoke testing",
            equipment_type: "dry_van"
          }
        }
      when 'api/v1/carriers'
        {
          carrier: {
            company_name: "Test Carrier #{Time.now.to_i}",
            phone: "555-0123",
            equipment_types: ["dry_van"],
            service_areas: ["TX", "OK"]
          }
        }
      when 'api/v1/users'
        unique_id = Time.now.to_i
        {
          user: {
            email: "testuser#{unique_id}@example.com",
            first_name: "Test",
            last_name: "User",
            role: "shipper"
          }
        }
      else
        # Generic test data
        { test: true, timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S%z') }
      end
    end

    def evaluate_response(response, endpoint)
      case endpoint[:category]
      when :list_resource
        response[:success] && [200].include?(response[:status])
      when :get_resource
        # 200 for found, 404 for not found are both acceptable
        [200, 404].include?(response[:status])
      when :create_resource
        [200, 201].include?(response[:status])
      when :update_resource
        [200, 404, 422].include?(response[:status]) # 422 for validation errors is acceptable
      when :delete_resource
        [200, 204, 404].include?(response[:status])
      else
        response[:success]
      end
    end
  end
end