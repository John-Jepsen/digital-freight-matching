
# frozen_string_literal: true

# Monitorable concern for comprehensive controller monitoring
module Monitorable
  extend ActiveSupport::Concern
  
  included do
    around_action :monitor_request_performance
    after_action :track_business_events
    rescue_from StandardError, with: :track_application_error
  end
  
  private
  
  # Monitor API request performance and track metrics
  def monitor_request_performance
    start_time = Time.current
    
    begin
      yield
      
      # Track successful request
      track_api_request_success(start_time)
      
    rescue StandardError => error
      # Track failed request 
      track_api_request_error(start_time, error)
      raise error
    end
  end
  
  # Track successful API requests
  def track_api_request_success(start_time)
    duration = Time.current - start_time
    status = response.status.to_s
    
    # Track response time
    Yabeda.freight_app.api_response_time_seconds.measure(
      { controller: controller_name, action: action_name, status: status },
      duration
    )
    
    # Track total API requests
    Yabeda.freight_app.api_requests_total.increment(
      endpoint: "#{controller_name}##{action_name}",
      status: status
    )
    
    # Log slow requests (SLA monitoring)
    if duration > slow_request_threshold
      Rails.logger.warn(
        "Slow request detected: #{controller_name}##{action_name} " \
        "took #{duration.round(3)}s (threshold: #{slow_request_threshold}s)"
      )
      
      Yabeda.freight_app.sla_violations_total.increment(
        sla_type: 'response_time',
        severity: determine_severity(duration)
      )
    end
  end
  
  # Track failed API requests
  def track_api_request_error(start_time, error)
    duration = Time.current - start_time
    status = '500' # Default to 500 for unhandled errors
    
    # Track response time even for errors
    Yabeda.freight_app.api_response_time_seconds.measure(
      { controller: controller_name, action: action_name, status: status },
      duration
    )
    
    # Track API request errors
    Yabeda.freight_app.api_requests_total.increment(
      endpoint: "#{controller_name}##{action_name}",
      status: status
    )
    
    # Track application errors
    Yabeda.freight_app.application_errors_total.increment(
      error_type: error.class.name,
      severity: 'error'
    )
    
    # Log error details
    Rails.logger.error(
      "Request error in #{controller_name}##{action_name}: " \
      "#{error.class.name} - #{error.message}"
    )
  end
  
  # Track business-specific events based on controller actions
  def track_business_events
    case "#{controller_name}##{action_name}"
    when 'auth#register'
      track_user_registration if response.successful?
    when 'auth#login'
      track_user_login if response.successful?
    when 'loads#create'
      track_load_posting if response.successful?
    when 'loads#book'
      track_load_booking if response.successful?
    when 'loads#complete'
      track_load_completion if response.successful?
    when 'loads#cancel'
      track_load_cancellation if response.successful?
    when 'matching#find_carriers_for_load'
      track_matching_attempt if response.successful?
    end
  rescue StandardError => error
    Rails.logger.error "Failed to track business event: #{error.message}"
  end
  
  # Track application errors and categorize them
  def track_application_error(error)
    # Avoid double render/redirect scenarios
    return if error.is_a?(AbstractController::DoubleRenderError)
    return if defined?(performed?) && performed?
    return if response.respond_to?(:committed?) && response.committed?

    case error
    when ActiveRecord::RecordNotFound
      render_not_found_error(error)
    when ActiveRecord::RecordInvalid
      render_validation_error(error)
    when Pundit::NotAuthorizedError
      render_authorization_error(error) 
    else
      render_internal_server_error(error)
    end
    
    # Track the specific error type
    Yabeda.freight_app.application_errors_total.increment(
      error_type: error.class.name,
      severity: determine_error_severity(error)
    )
  end
  
  # Business event tracking methods
  def track_user_registration
    Yabeda.freight_app.user_registrations_total.increment
  end
  
  def track_user_login
    Yabeda.freight_app.user_logins_total.increment
  end
  
  def track_load_posting
    Yabeda.freight_app.load_posts_total.increment
    
    # Track load value if available
    if params[:load] && params[:load][:total_rate]
      load_value = params[:load][:total_rate].to_f
      load_type = params[:load][:load_type] || 'standard'
      
      Yabeda.freight_app.load_value_dollars.measure(
        { load_type: load_type },
        load_value
      )
    end
  end
  
  def track_load_booking
    Yabeda.freight_app.load_bookings_total.increment
  end
  
  def track_load_completion
    Yabeda.freight_app.load_completions_total.increment
  end
  
  def track_load_cancellation
    Yabeda.freight_app.load_cancellations_total.increment
  end
  
  def track_matching_attempt
    if response_data_indicates_successful_match?
      Yabeda.freight_app.load_matches_total.increment
    else
      Yabeda.freight_app.failed_load_matches_total.increment
    end
  end
  
  # Helper methods
  def slow_request_threshold
    case "#{controller_name}##{action_name}"
    when /analytics/, /reports/
      5.0 # Analytics endpoints can be slower
    when /search/, /matching/
      2.0 # Search and matching should be reasonably fast
    else
      1.0 # Standard API endpoints
    end
  end
  
  def determine_severity(duration)
    case duration
    when 0..2
      'low'
    when 2..5
      'medium'
    when 5..10
      'high'
    else
      'critical'
    end
  end
  
  def determine_error_severity(error)
    case error
    when ActiveRecord::RecordNotFound, 
         Pundit::NotAuthorizedError
      'low'
    when ActiveRecord::RecordInvalid
      'medium'
    else
      'high'
    end
  end
  
  def response_data_indicates_successful_match?
    # Check if response contains successful match data
    return false unless response.successful?
    
    begin
      data = JSON.parse(response.body)
      carriers = data.dig('carriers') || data.dig('matches') || []
      carriers.any?
    rescue JSON::ParserError
      false
    end
  end
  
  # Standard error response methods
  def render_not_found_error(error)
    render json: {
      error: 'Resource not found',
      message: error.message
    }, status: :not_found
  end
  
  def render_validation_error(error)
    render json: {
      error: 'Validation failed',
      message: error.message,
      details: error.record&.errors
    }, status: :unprocessable_entity
  end
  
  def render_authorization_error(error)
    render json: {
      error: 'Access denied',
      message: 'You are not authorized to perform this action'
    }, status: :forbidden
  end
  
  def render_internal_server_error(error)
    return if defined?(performed?) && performed?
    return if response.respond_to?(:committed?) && response.committed?

    Rails.logger.error "Internal server error: #{error.message}"
    Rails.logger.error error.backtrace.join("\n") if Rails.env.development?
    
    render json: {
      error: 'Internal server error',
      message: Rails.env.development? ? error.message : 'An unexpected error occurred'
    }, status: :internal_server_error
  end
end

