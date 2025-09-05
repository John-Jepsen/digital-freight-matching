# Database connection pool monitoring and optimization
# Implements connection leak detection and performance monitoring

Rails.application.configure do
  # Connection pool monitoring configuration
  config.after_initialize do
    # Set up connection pool monitoring
    DatabasePoolMonitor.setup if defined?(DatabasePoolMonitor)
    
    # Configure automatic connection reaping
    ActiveRecord::Base.connection_pool.automatic_reconnect = true
    
    # Log slow queries in development and test
    if Rails.env.development? || Rails.env.test?
      ActiveSupport::Notifications.subscribe "sql.active_record" do |name, start, finish, id, payload|
        duration = (finish - start) * 1000
        if duration > 1000 # Log queries taking longer than 1 second
          Rails.logger.warn "SLOW QUERY (#{duration.round(2)}ms): #{payload[:sql]}"
        end
      end
    end
  end
end

# Connection pool monitoring service
class DatabasePoolMonitor
  class << self
    def setup
      # Monitor connection pool usage every 30 seconds
      Thread.new do
        loop do
          begin
            monitor_pools
            sleep 30
          rescue => e
            Rails.logger.error "Database pool monitoring error: #{e.message}"
          end
        end
      end
    end
    
    private
    
    def monitor_pools
      # Monitor primary database pool
      monitor_pool('primary', ActiveRecord::Base.connection_pool)
      
      # Monitor replica pool if configured
      if defined?(ApplicationRecord) && ApplicationRecord.connected_to_many?
        replica_pool = ApplicationRecord.connection_handler.retrieve_connection_pool('ApplicationRecord', :reading)
        monitor_pool('replica', replica_pool) if replica_pool
      end
    rescue => e
      Rails.logger.error "Error monitoring database pools: #{e.message}"
    end
    
    def monitor_pool(name, pool)
      return unless pool
      
      stat = pool.stat
      size = stat[:size]
      checked_out = stat[:checked_out]
      checked_in = stat[:checked_in]
      available = stat[:available]
      
      # Calculate pool utilization
      utilization = (checked_out.to_f / size * 100).round(2)
      
      # Log pool statistics
      Rails.logger.info "DB Pool [#{name}]: Size=#{size}, Used=#{checked_out}, Available=#{available}, Utilization=#{utilization}%"
      
      # Alert on high utilization
      if utilization > 80
        Rails.logger.warn "HIGH DB POOL UTILIZATION [#{name}]: #{utilization}% - Consider increasing pool size"
      end
      
      # Alert on pool exhaustion
      if available == 0
        Rails.logger.error "DB POOL EXHAUSTED [#{name}]: No available connections - Potential connection leak!"
      end
      
      # Update metrics if Yabeda is available
      if defined?(Yabeda)
        Yabeda.database_metrics.connection_pool_size.set(size, pool: name)
        Yabeda.database_metrics.connection_pool_used.set(checked_out, pool: name)
        Yabeda.database_metrics.connection_pool_available.set(available, pool: name)
        Yabeda.database_metrics.connection_pool_utilization.set(utilization, pool: name)
      end
    end
  end
end

# Add database metrics to Yabeda if available
if defined?(Yabeda)
  Yabeda.configure do
    group :database_metrics do
      gauge :connection_pool_size, comment: "Database connection pool size", tags: [:pool]
      gauge :connection_pool_used, comment: "Database connections in use", tags: [:pool]
      gauge :connection_pool_available, comment: "Available database connections", tags: [:pool]
      gauge :connection_pool_utilization, comment: "Database connection pool utilization percentage", tags: [:pool]
      
      histogram :database_connection_checkout_duration,
                comment: "Time to checkout a database connection",
                tags: [:pool],
                buckets: [0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0, 5.0]
    end
  end
  
  # Monitor connection checkout times
  ActiveSupport::Notifications.subscribe "checkout.active_record" do |name, start, finish, id, payload|
    duration = finish - start
    pool_name = payload[:connection_name] || 'primary'
    
    Yabeda.database_metrics.database_connection_checkout_duration.observe(
      duration,
      pool: pool_name
    )
    
    # Log slow checkouts
    if duration > 0.1 # 100ms
      Rails.logger.warn "SLOW CONNECTION CHECKOUT (#{(duration * 1000).round(2)}ms) for pool: #{pool_name}"
    end
  end
end