# frozen_string_literal: true

# Monitoring and Metrics Configuration
require 'yabeda'
require 'yabeda/prometheus'
require 'yabeda/rails'
require 'yabeda/sidekiq'

# Configure Yabeda for comprehensive monitoring
Yabeda.configure do
  # Application-level metrics
  group :freight_app do
    # Business metrics
    counter :load_posts_total, comment: "Total number of loads posted"
    counter :load_matches_total, comment: "Total number of successful load matches"
    counter :load_bookings_total, comment: "Total number of load bookings"
    counter :load_completions_total, comment: "Total number of completed loads"
    counter :load_cancellations_total, comment: "Total number of cancelled loads"
    
    # User engagement metrics
    counter :user_registrations_total, comment: "Total number of user registrations"
    counter :user_logins_total, comment: "Total number of user logins"
    counter :api_requests_total, comment: "Total number of API requests", tags: [:endpoint, :status]
    
    # Performance metrics
    histogram :api_response_time_seconds, 
              comment: "API response time in seconds",
              tags: [:controller, :action, :status],
              buckets: [0.1, 0.25, 0.5, 1, 2.5, 5, 10]
              
    histogram :database_query_duration_seconds,
              comment: "Database query duration in seconds",
              tags: [:operation],
              buckets: [0.01, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5]
    
    # System health metrics
    gauge :active_users_count, comment: "Number of currently active users"
    gauge :pending_loads_count, comment: "Number of loads waiting for carriers"
    gauge :active_shipments_count, comment: "Number of shipments in transit"
    gauge :available_carriers_count, comment: "Number of available carriers"
    
    # Resource utilization metrics
    gauge :memory_usage_bytes, comment: "Current memory usage in bytes"
    gauge :memory_limit_bytes, comment: "Memory limit in bytes"
    gauge :cpu_usage_percent, comment: "Current CPU usage percentage"
    gauge :disk_usage_bytes, comment: "Current disk usage in bytes", tags: [:mount_point]
    gauge :disk_free_bytes, comment: "Available disk space in bytes", tags: [:mount_point]
    
    # Container and scaling metrics
    gauge :container_restarts_total, comment: "Total number of container restarts"
    gauge :pod_ready_replicas, comment: "Number of ready pod replicas", tags: [:deployment]
    gauge :pod_desired_replicas, comment: "Desired number of pod replicas", tags: [:deployment]
    counter :scaling_events_total, comment: "Total number of scaling events", tags: [:direction, :deployment]
    
    # Revenue and financial metrics
    histogram :load_value_dollars,
              comment: "Load value distribution in dollars",
              tags: [:load_type],
              buckets: [100, 500, 1000, 2500, 5000, 10000, 25000, 50000]
              
    gauge :platform_revenue_total_dollars, comment: "Total platform revenue in dollars"
    gauge :average_load_value_dollars, comment: "Average load value in dollars"
    
    # Error tracking
    counter :application_errors_total, 
            comment: "Total number of application errors",
            tags: [:error_type, :severity]
            
    counter :failed_load_matches_total, comment: "Total number of failed load matches"
    counter :payment_failures_total, comment: "Total number of payment failures"
    
    # SLA and availability metrics
    gauge :system_uptime_seconds, comment: "System uptime in seconds"
    counter :sla_violations_total, 
            comment: "Total number of SLA violations",
            tags: [:sla_type, :severity]
  end
  
  # Carrier-specific metrics
  group :carrier_metrics do
    gauge :carrier_utilization_rate, 
          comment: "Carrier utilization rate percentage",
          tags: [:carrier_id]
          
    histogram :delivery_time_hours,
              comment: "Delivery time in hours",
              tags: [:carrier_id, :route_type],
              buckets: [1, 4, 8, 12, 24, 48, 72, 168]
              
    counter :carrier_performance_scores, 
            comment: "Carrier performance scores",
            tags: [:carrier_id, :score_range]
  end
  
  # Geographic and route metrics
  group :route_metrics do
    histogram :route_distance_miles,
              comment: "Route distance in miles", 
              tags: [:route_type],
              buckets: [10, 50, 100, 250, 500, 1000, 2000]
              
    histogram :route_optimization_savings_percent,
              comment: "Route optimization savings percentage",
              buckets: [5, 10, 15, 20, 25, 30, 40, 50]
  end
end

# Configure Prometheus exporter
Yabeda::Prometheus.configure do |config|
  config.comment_enabled = true
end

# Business metrics collector service
class BusinessMetricsCollector
  class << self
    # Collect real-time business metrics
    def collect_all_metrics
      collect_user_metrics
      collect_load_metrics
      collect_financial_metrics
      collect_system_health_metrics
      collect_carrier_metrics
      collect_resource_metrics
    rescue StandardError => e
      Rails.logger.error "Failed to collect business metrics: #{e.message}"
      Yabeda.freight_app.application_errors_total.increment(
        error_type: 'metrics_collection',
        severity: 'warning'
      )
    end
    
    private
    
    def collect_user_metrics
      Yabeda.freight_app.active_users_count.set(active_users_count)
    end
    
    def collect_load_metrics
      Yabeda.freight_app.pending_loads_count.set(pending_loads_count)
      Yabeda.freight_app.active_shipments_count.set(active_shipments_count)
      Yabeda.freight_app.available_carriers_count.set(available_carriers_count)
    end
    
    def collect_financial_metrics
      return unless defined?(Load)
      
      total_revenue = Load.joins(:payments).where(payments: { status: 'completed' })
                         .sum('payments.amount')
      avg_load_value = Load.average(:total_rate) || 0
      
      Yabeda.freight_app.platform_revenue_total_dollars.set(total_revenue)
      Yabeda.freight_app.average_load_value_dollars.set(avg_load_value)
    end
    
    def collect_system_health_metrics
      uptime = Time.current - Rails.application.started_at rescue 0
      Yabeda.freight_app.system_uptime_seconds.set(uptime)
    end
    
    def collect_carrier_metrics
      return unless defined?(Carrier)
      
      Carrier.includes(:loads).find_each do |carrier|
        completed_loads = carrier.loads.where(status: 'completed').count
        total_loads = carrier.loads.count
        utilization = total_loads > 0 ? (completed_loads.to_f / total_loads * 100) : 0
        
        Yabeda.carrier_metrics.carrier_utilization_rate.set(
          utilization,
          carrier_id: carrier.id.to_s
        )
      end
    rescue NameError
      # Models not defined yet, skip carrier metrics
      nil
    end
    
    # Helper methods for metric calculations
    def active_users_count
      return 0 unless defined?(User)
      User.where('last_sign_in_at > ?', 1.hour.ago).count
    rescue NameError
      0
    end
    
    def pending_loads_count  
      return 0 unless defined?(Load)
      Load.where(status: 'posted').count
    rescue NameError
      0
    end
    
    def active_shipments_count
      return 0 unless defined?(Shipment)
      Shipment.where(status: ['picked_up', 'in_transit']).count
    rescue NameError
      0
    end
    
    def available_carriers_count
      return 0 unless defined?(Carrier)
      Carrier.where(status: 'available').count  
    rescue NameError
      0
    end
    
    def collect_resource_metrics
      # Memory metrics
      begin
        memory_stats = `cat /proc/meminfo`.lines.map { |line| line.split }
        memory_total = memory_stats.find { |stat| stat[0] == 'MemTotal:' }&.dig(1)&.to_i&.*(1024)
        memory_available = memory_stats.find { |stat| stat[0] == 'MemAvailable:' }&.dig(1)&.to_i&.*(1024)
        
        if memory_total && memory_available
          memory_used = memory_total - memory_available
          Yabeda.freight_app.memory_usage_bytes.set(memory_used)
          Yabeda.freight_app.memory_limit_bytes.set(memory_total)
        end
      rescue StandardError => e
        Rails.logger.warn "Failed to collect memory metrics: #{e.message}"
      end
      
      # CPU metrics
      begin
        cpu_usage = `top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//'`.to_f
        Yabeda.freight_app.cpu_usage_percent.set(cpu_usage)
      rescue StandardError => e
        Rails.logger.warn "Failed to collect CPU metrics: #{e.message}"
      end
      
      # Disk metrics
      begin
        disk_info = `df -B1`.lines[1..-1] # Skip header
        disk_info.each do |line|
          parts = line.split
          next if parts.length < 6
          
          mount_point = parts[5]
          used_bytes = parts[2].to_i
          available_bytes = parts[3].to_i
          
          Yabeda.freight_app.disk_usage_bytes.set(used_bytes, mount_point: mount_point)
          Yabeda.freight_app.disk_free_bytes.set(available_bytes, mount_point: mount_point)
        end
      rescue StandardError => e
        Rails.logger.warn "Failed to collect disk metrics: #{e.message}"
      end
      
      # Container restart count (if running in Kubernetes)
      if ENV['KUBERNETES_SERVICE_HOST']
        begin
          restart_count = ENV['CONTAINER_RESTART_COUNT']&.to_i || 0
          Yabeda.freight_app.container_restarts_total.set(restart_count)
        rescue StandardError => e
          Rails.logger.warn "Failed to collect container metrics: #{e.message}"
        end
      end
    end
  end
end

# Schedule metrics collection
if defined?(Sidekiq)
  require 'sidekiq-cron'
  
  # Collect business metrics every 5 minutes
  Sidekiq::Cron::Job.create(
    'business_metrics_collection',
    '*/5 * * * *', # Every 5 minutes
    'BusinessMetricsCollectionJob'
  )
end

Rails.logger.info "Monitoring system initialized with comprehensive APM and business metrics"