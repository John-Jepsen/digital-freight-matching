# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'logger'

# Main API Smoke Testing Framework
# Provides comprehensive testing of API endpoints with different test strategies
module ApiSmokeTestFramework
  class Configuration
    attr_accessor :base_url, :timeout, :environment, :auth_credentials, :logger

    def initialize
      @base_url = ENV.fetch('SMOKE_TEST_BASE_URL', 'http://localhost:3001')
      @timeout = ENV.fetch('SMOKE_TEST_TIMEOUT', '30').to_i
      @environment = ENV.fetch('RAILS_ENV', 'test')
      @auth_credentials = {}
      @logger = Logger.new(STDOUT)
      @logger.level = Logger::INFO
    end
  end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end
  end

  # Endpoint discovery and categorization
  class EndpointDiscovery
    def self.discover_endpoints
      return [] unless defined?(Rails)

      endpoints = []
      Rails.application.routes.routes.each do |route|
        next unless route.path.spec.to_s.start_with?('/api/')
        
        endpoints << {
          path: route.path.spec.to_s.gsub(/\(\.:format\)$/, ''),
          method: route.verb.downcase,
          controller: route.defaults[:controller],
          action: route.defaults[:action],
          category: categorize_endpoint(route)
        }
      end
      
      endpoints.uniq { |ep| [ep[:path], ep[:method]] }
    end

    private

    def self.categorize_endpoint(route)
      path = route.path.spec.to_s
      controller = route.defaults[:controller]
      action = route.defaults[:action]

      case
      when path.include?('health') || action == 'health'
        :health_check
      when path.include?('auth') || controller&.include?('auth')
        :authentication
      when path.include?('analytics')
        :analytics
      when route.verb.match?(/GET/i) && action == 'index'
        :list_resource
      when route.verb.match?(/GET/i) && action == 'show'
        :get_resource
      when route.verb.match?(/POST/i) && action == 'create'
        :create_resource
      when route.verb.match?(/PUT|PATCH/i)
        :update_resource
      when route.verb.match?(/DELETE/i)
        :delete_resource
      else
        :custom_action
      end
    end
  end

  # HTTP client for making API requests
  class HttpClient
    def initialize(config = ApiSmokeTestFramework.configuration)
      @config = config
      @base_uri = URI(@config.base_url)
    end

    def make_request(method, path, options = {})
      uri = URI.join(@base_uri, path)
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == 'https'
      http.read_timeout = @config.timeout
      http.open_timeout = @config.timeout

      request = build_request(method, uri, options)
      
      start_time = Time.now
      response = http.request(request)
      end_time = Time.now

      {
        status: response.code.to_i,
        headers: response.to_hash,
        body: parse_response_body(response),
        response_time_ms: ((end_time - start_time) * 1000).round(2),
        success: response.code.to_i < 400
      }
    rescue => e
      {
        status: 0,
        headers: {},
        body: nil,
        response_time_ms: 0,
        success: false,
        error: e.message
      }
    end

    private

    def build_request(method, uri, options)
      request_class = case method.to_s.upcase
                     when 'GET' then Net::HTTP::Get
                     when 'POST' then Net::HTTP::Post
                     when 'PUT' then Net::HTTP::Put
                     when 'PATCH' then Net::HTTP::Patch
                     when 'DELETE' then Net::HTTP::Delete
                     else raise ArgumentError, "Unsupported HTTP method: #{method}"
                     end

      request = request_class.new(uri)
      request['Content-Type'] = 'application/json'
      request['Accept'] = 'application/json'

      # Add authentication if provided
      if options[:auth_token]
        request['Authorization'] = "Bearer #{options[:auth_token]}"
      end

      # Add custom headers
      if options[:headers]
        options[:headers].each { |key, value| request[key] = value }
      end

      # Add request body for POST/PUT/PATCH
      if options[:body] && %w[POST PUT PATCH].include?(method.to_s.upcase)
        request.body = options[:body].is_a?(String) ? options[:body] : options[:body].to_json
      end

      request
    end

    def parse_response_body(response)
      return nil if response.body.nil? || response.body.empty?
      
      if response['content-type']&.include?('application/json')
        JSON.parse(response.body)
      else
        response.body
      end
    rescue JSON::ParserError
      response.body
    end
  end
end