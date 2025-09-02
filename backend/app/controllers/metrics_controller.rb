# frozen_string_literal: true

# Metrics controller for Prometheus scraping
class MetricsController < ApplicationController
  # Skip authentication for metrics endpoint
  skip_before_action :authenticate_user!, only: [:index]
  
  # GET /metrics
  # Prometheus metrics endpoint
  def index
    # Ensure business metrics are collected before scraping
    BusinessMetricsCollector.collect_all_metrics
    
    # Return Prometheus-formatted metrics
    metrics_output = Yabeda::Prometheus::Exporter.built_in_registry.metrics
    
    render plain: metrics_output, content_type: 'text/plain; version=0.0.4'
  rescue StandardError => error
    Rails.logger.error "Failed to generate metrics: #{error.message}"
    
    # Track the error
    Yabeda.freight_app.application_errors_total.increment(
      error_type: 'metrics_generation',
      severity: 'high'
    ) if defined?(Yabeda)
    
    render plain: "# Error generating metrics\n", 
           content_type: 'text/plain; version=0.0.4',
           status: :internal_server_error
  end
end