# frozen_string_literal: true

# Background job for collecting business metrics
class BusinessMetricsCollectionJob < ApplicationJob
  queue_as :metrics
  
  # Job should not retry automatically to avoid metric duplication
  discard_on StandardError
  
  def perform
    Rails.logger.info "Starting business metrics collection..."
    
    start_time = Time.current
    
    begin
      BusinessMetricsCollector.collect_all_metrics
      
      duration = Time.current - start_time
      Rails.logger.info "Business metrics collection completed in #{duration.round(3)}s"
      
      # Track the collection job performance
      Yabeda.freight_app.api_response_time_seconds.measure(
        duration,
        controller: 'background_jobs',
        action: 'metrics_collection',
        status: 'success'
      )
      
    rescue StandardError => error
      duration = Time.current - start_time
      Rails.logger.error "Business metrics collection failed after #{duration.round(3)}s: #{error.message}"
      
      # Track the failure
      Yabeda.freight_app.application_errors_total.increment(
        error_type: 'metrics_collection_job',
        severity: 'high'
      )
      
      Yabeda.freight_app.api_response_time_seconds.measure(
        duration,
        controller: 'background_jobs',
        action: 'metrics_collection',
        status: 'error'
      )
      
      # Re-raise to ensure job is marked as failed
      raise error
    end
  end
end