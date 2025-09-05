# Intelligent database router for read/write splitting and load balancing
# Handles automatic failover and query routing optimization

class DatabaseRouter
  class << self
    # Route read operations to replicas with automatic failover
    def with_read_routing(&block)
      if replica_healthy?
        ApplicationRecord.connected_to(role: :reading, &block)
      else
        Rails.logger.warn "Replica unhealthy, routing read to primary"
        ApplicationRecord.connected_to(role: :writing, &block)
      end
    rescue ActiveRecord::ConnectionNotEstablished => e
      Rails.logger.error "Replica connection failed, falling back to primary: #{e.message}"
      ApplicationRecord.connected_to(role: :writing, &block)
    end
    
    # Force write operations to primary database
    def with_write_routing(&block)
      ApplicationRecord.connected_to(role: :writing, &block)
    end
    
    # Execute read operations with load balancing across replicas
    def with_load_balanced_read(&block)
      replica_pool = select_best_replica
      if replica_pool && replica_healthy?
        ApplicationRecord.connected_to(role: :reading, &block)
      else
        Rails.logger.warn "No healthy replicas available, routing to primary"
        ApplicationRecord.connected_to(role: :writing, &block)
      end
    rescue => e
      Rails.logger.error "Load balanced read failed, falling back to primary: #{e.message}"
      ApplicationRecord.connected_to(role: :writing, &block)
    end
    
    # Health check for replica databases
    def replica_healthy?
      return false unless replica_configured?
      
      @replica_health_cache ||= {}
      cache_key = 'replica_health'
      
      # Use cached health status for 30 seconds to avoid excessive health checks
      if @replica_health_cache[cache_key] && 
         @replica_health_cache[cache_key][:timestamp] > 30.seconds.ago
        return @replica_health_cache[cache_key][:healthy]
      end
      
      healthy = check_replica_health
      @replica_health_cache[cache_key] = {
        healthy: healthy,
        timestamp: Time.current
      }
      
      healthy
    end
    
    # Check if replica is configured
    def replica_configured?
      ApplicationRecord.connected_to_many? rescue false
    end
    
    # Get database connection statistics
    def connection_stats
      stats = {}
      
      # Primary database stats
      primary_pool = ActiveRecord::Base.connection_pool
      stats[:primary] = pool_stats(primary_pool)
      
      # Replica database stats
      if replica_configured?
        begin
          replica_pool = ApplicationRecord.connection_handler.retrieve_connection_pool('ApplicationRecord', :reading)
          stats[:replica] = pool_stats(replica_pool) if replica_pool
        rescue => e
          Rails.logger.error "Error getting replica stats: #{e.message}"
          stats[:replica] = { error: e.message }
        end
      end
      
      stats
    end
    
    # Execute query with intelligent routing based on query type
    def execute_with_routing(sql_or_model_method, *args, &block)
      if write_operation?(sql_or_model_method)
        with_write_routing(&block)
      else
        with_read_routing(&block)
      end
    end
    
    # Failover mechanism - switch all reads to primary if replicas fail
    def enable_primary_only_mode!
      @primary_only_mode = true
      @primary_only_started_at = Time.current
      Rails.logger.warn "FAILOVER: Enabled primary-only mode due to replica failures"
    end
    
    def disable_primary_only_mode!
      @primary_only_mode = false
      @primary_only_started_at = nil
      Rails.logger.info "FAILOVER: Disabled primary-only mode, replicas available"
    end
    
    def primary_only_mode?
      @primary_only_mode == true
    end
    
    # Automatic recovery from primary-only mode
    def check_and_recover_from_failover
      return unless primary_only_mode?
      return unless @primary_only_started_at && @primary_only_started_at < 5.minutes.ago
      
      if replica_healthy?
        disable_primary_only_mode!
      end
    end
    
    private
    
    def check_replica_health
      return false unless replica_configured?
      
      ApplicationRecord.connected_to(role: :reading) do
        # Simple health check query
        ApplicationRecord.connection.execute("SELECT 1")
        true
      end
    rescue => e
      Rails.logger.error "Replica health check failed: #{e.message}"
      false
    end
    
    def select_best_replica
      # For now, return the configured replica
      # In the future, this could implement round-robin or least-connections logic
      return nil unless replica_configured?
      
      begin
        ApplicationRecord.connection_handler.retrieve_connection_pool('ApplicationRecord', :reading)
      rescue => e
        Rails.logger.error "Error selecting replica: #{e.message}"
        nil
      end
    end
    
    def pool_stats(pool)
      return nil unless pool
      
      stat = pool.stat
      {
        size: stat[:size],
        checked_out: stat[:checked_out],
        checked_in: stat[:checked_in],
        available: stat[:available],
        utilization: (stat[:checked_out].to_f / stat[:size] * 100).round(2)
      }
    rescue => e
      Rails.logger.error "Error getting pool stats: #{e.message}"
      { error: e.message }
    end
    
    def write_operation?(sql_or_method)
      return false unless sql_or_method.is_a?(String)
      
      sql = sql_or_method.strip.upcase
      sql.start_with?('INSERT', 'UPDATE', 'DELETE', 'CREATE', 'DROP', 'ALTER', 'TRUNCATE')
    end
  end
end

# Automatic failover monitoring
if Rails.env.production? || Rails.env.staging?
  Thread.new do
    loop do
      begin
        DatabaseRouter.check_and_recover_from_failover
        sleep 60 # Check every minute
      rescue => e
        Rails.logger.error "Failover monitoring error: #{e.message}"
      end
    end
  end
end

# Add database routing metrics to monitoring
if defined?(Yabeda)
  # Track routing decisions
  Yabeda.configure do
    group :database_router do
      counter :queries_routed_to_primary, comment: "Queries routed to primary database"
      counter :queries_routed_to_replica, comment: "Queries routed to replica database"
      counter :replica_health_checks, comment: "Replica health check attempts", tags: [:status]
      counter :failover_events, comment: "Database failover events", tags: [:type]
      gauge :primary_only_mode, comment: "Whether system is in primary-only mode"
    end
  end
  
  # Instrument routing decisions
  class DatabaseRouter
    class << self
      alias_method :with_read_routing_original, :with_read_routing
      alias_method :with_write_routing_original, :with_write_routing
      
      def with_read_routing(&block)
        if replica_healthy? && !primary_only_mode?
          Yabeda.database_router.queries_routed_to_replica.increment
        else
          Yabeda.database_router.queries_routed_to_primary.increment
        end
        with_read_routing_original(&block)
      end
      
      def with_write_routing(&block)
        Yabeda.database_router.queries_routed_to_primary.increment
        with_write_routing_original(&block)
      end
      
      alias_method :enable_primary_only_mode_original!, :enable_primary_only_mode!
      alias_method :disable_primary_only_mode_original!, :disable_primary_only_mode!
      
      def enable_primary_only_mode!
        Yabeda.database_router.failover_events.increment(type: 'primary_only_enabled')
        Yabeda.database_router.primary_only_mode.set(1)
        enable_primary_only_mode_original!
      end
      
      def disable_primary_only_mode!
        Yabeda.database_router.failover_events.increment(type: 'primary_only_disabled')
        Yabeda.database_router.primary_only_mode.set(0)
        disable_primary_only_mode_original!
      end
    end
  end
end