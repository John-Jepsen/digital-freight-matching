class DatabasePerformanceMonitorService
  include Singleton
  
  attr_reader :slow_queries, :query_stats
  
  def initialize
    @slow_queries = []
    @query_stats = Hash.new { |h, k| h[k] = { count: 0, total_time: 0.0 } }
    @threshold_ms = 1000 # Log queries slower than 1 second
  end
  
  def log_query(query_name, execution_time_ms, sql = nil)
    # Update statistics
    @query_stats[query_name][:count] += 1
    @query_stats[query_name][:total_time] += execution_time_ms
    
    # Log slow queries
    if execution_time_ms > @threshold_ms
      slow_query = {
        query_name: query_name,
        execution_time_ms: execution_time_ms,
        timestamp: Time.current,
        sql: sql
      }
      
      @slow_queries << slow_query
      @slow_queries = @slow_queries.last(100) # Keep only last 100 slow queries
      
      Rails.logger.warn "Slow Query Detected: #{query_name} - #{execution_time_ms.round(2)}ms"
      Rails.logger.debug "SQL: #{sql}" if sql.present?
    end
  end
  
  def analyze_query_with_explain(scope, query_name = nil)
    return unless Rails.env.development? || Rails.env.test?
    
    begin
      sql = scope.to_sql
      explain_result = ActiveRecord::Base.connection.execute("EXPLAIN ANALYZE #{sql}")
      
      Rails.logger.info "=== Query Analysis: #{query_name || 'Unknown'} ==="
      explain_result.each { |row| Rails.logger.info row['QUERY PLAN'] }
      Rails.logger.info "=== End Query Analysis ==="
      
      # Extract execution time from EXPLAIN ANALYZE output
      if explain_result.any?
        last_line = explain_result.to_a.last['QUERY PLAN']
        if match = last_line.match(/Execution Time: ([\d.]+) ms/)
          execution_time = match[1].to_f
          log_query(query_name || 'Unknown', execution_time, sql)
        end
      end
    rescue StandardError => e
      Rails.logger.error "Failed to analyze query: #{e.message}"
    end
  end
  
  def get_performance_summary
    summary = {}
    
    @query_stats.each do |query_name, stats|
      summary[query_name] = {
        count: stats[:count],
        total_time_ms: stats[:total_time].round(2),
        average_time_ms: (stats[:total_time] / stats[:count]).round(2)
      }
    end
    
    {
      summary: summary,
      slow_queries_count: @slow_queries.count,
      recent_slow_queries: @slow_queries.last(10)
    }
  end
  
  def reset_stats
    @slow_queries.clear
    @query_stats.clear
  end
  
  def set_threshold(threshold_ms)
    @threshold_ms = threshold_ms
  end
  
  # Middleware method to wrap service calls with performance monitoring
  def self.monitor_performance(service_name, &block)
    start_time = Time.current
    result = block.call
    execution_time = (Time.current - start_time) * 1000
    
    instance.log_query(service_name, execution_time)
    
    result
  end
  
  # Method to monitor ActiveRecord queries
  def self.monitor_query(query_name, scope)
    start_time = Time.current
    result = scope.to_a  # Execute the query
    execution_time = (Time.current - start_time) * 1000
    
    instance.log_query(query_name, execution_time, scope.to_sql)
    instance.analyze_query_with_explain(scope, query_name)
    
    result
  end
end