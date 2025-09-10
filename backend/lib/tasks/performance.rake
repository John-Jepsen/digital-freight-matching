namespace :db do
  namespace :performance do
    desc "Analyze database performance and show statistics"
    task analyze: :environment do
      puts "=== Database Performance Analysis ==="
      puts
      
      # Get performance statistics from monitor
      monitor = DatabasePerformanceMonitorService.instance
      summary = monitor.get_performance_summary
      
      puts "Query Performance Summary:"
      puts "-" * 50
      
      summary[:summary].each do |query_name, stats|
        puts "#{query_name.ljust(30)}: #{stats[:count]} queries, avg: #{stats[:average_time_ms]}ms"
      end
      
      puts
      puts "Slow Queries (>1s): #{summary[:slow_queries_count]}"
      
      if summary[:recent_slow_queries].any?
        puts
        puts "Recent Slow Queries:"
        puts "-" * 50
        summary[:recent_slow_queries].each do |query|
          puts "#{query[:query_name]} - #{query[:execution_time_ms].round(2)}ms at #{query[:timestamp]}"
        end
      end
      
      puts
      puts "=== Index Usage Analysis ==="
      analyze_index_usage
      
      puts
      puts "=== Missing Index Recommendations ==="
      recommend_missing_indexes
    end
    
    desc "Run performance benchmarks"
    task benchmark: :environment do
      puts "=== Running Performance Benchmarks ==="
      puts
      
      # Create test data if needed
      setup_benchmark_data
      
      # Benchmark load search
      puts "Load Search Benchmark:"
      puts "-" * 30
      benchmark_load_search
      
      puts
      puts "Carrier Matching Benchmark:"
      puts "-" * 30
      benchmark_carrier_matching
      
      puts
      puts "Geographic Query Benchmark:"
      puts "-" * 30
      benchmark_geographic_queries
    end
    
    desc "Reset performance statistics"
    task reset_stats: :environment do
      DatabasePerformanceMonitorService.instance.reset_stats
      puts "Performance statistics reset."
    end
    
    desc "Show current slow query threshold"
    task show_threshold: :environment do
      monitor = DatabasePerformanceMonitorService.instance
      puts "Current slow query threshold: #{monitor.instance_variable_get(:@threshold_ms)}ms"
    end
    
    desc "Set slow query threshold (THRESHOLD_MS=1000)"
    task set_threshold: :environment do
      threshold = ENV['THRESHOLD_MS']&.to_i || 1000
      DatabasePerformanceMonitorService.instance.set_threshold(threshold)
      puts "Slow query threshold set to: #{threshold}ms"
    end
    
    private
    
    def analyze_index_usage
      # Query to check index usage (PostgreSQL specific)
      result = ActiveRecord::Base.connection.execute(<<~SQL)
        SELECT
          schemaname,
          tablename,
          indexname,
          idx_scan as index_scans,
          idx_tup_read as tuples_read,
          idx_tup_fetch as tuples_fetched
        FROM pg_stat_user_indexes
        WHERE schemaname = 'public'
        AND tablename IN ('loads', 'carriers', 'vehicles', 'drivers', 'matches')
        ORDER BY idx_scan DESC;
      SQL
      
      if result.any?
        puts "Index Usage Statistics:"
        printf "%-20s %-15s %-30s %10s %12s %12s\n", 
               "Table", "Schema", "Index", "Scans", "Tuples Read", "Tuples Fetched"
        puts "-" * 100
        
        result.each do |row|
          printf "%-20s %-15s %-30s %10s %12s %12s\n",
                 row['tablename'], row['schemaname'], row['indexname'],
                 row['index_scans'], row['tuples_read'], row['tuples_fetched']
        end
      else
        puts "No index usage statistics available."
      end
    end
    
    def recommend_missing_indexes
      recommendations = []
      
      # Check for common query patterns without proper indexes
      
      # Load search patterns
      load_query_result = ActiveRecord::Base.connection.execute(<<~SQL)
        EXPLAIN (FORMAT JSON) 
        SELECT * FROM loads 
        WHERE status = 'posted' 
        AND equipment_type = 'dry_van' 
        AND pickup_state = 'TX'
        LIMIT 10;
      SQL
      
      if load_query_result.first['QUERY PLAN'].to_s.include?('Seq Scan')
        recommendations << "Consider adding composite index on loads(status, equipment_type, pickup_state)"
      end
      
      # Carrier matching patterns
      carrier_query_result = ActiveRecord::Base.connection.execute(<<~SQL)
        EXPLAIN (FORMAT JSON)
        SELECT * FROM carriers 
        WHERE is_active = true 
        AND is_verified = true 
        AND safety_rating = 'satisfactory';
      SQL
      
      if carrier_query_result.first['QUERY PLAN'].to_s.include?('Seq Scan')
        recommendations << "Consider adding composite index on carriers(is_active, is_verified, safety_rating)"
      end
      
      if recommendations.any?
        recommendations.each { |rec| puts "- #{rec}" }
      else
        puts "No obvious missing indexes detected."
      end
    rescue => e
      puts "Error analyzing missing indexes: #{e.message}"
    end
    
    def setup_benchmark_data
      return if Load.count > 100 && Carrier.count > 50
      
      puts "Setting up benchmark data..."
      
      # Create shippers
      shippers = 5.times.map do |i|
        Shipper.find_or_create_by(company_name: "Test Shipper #{i}") do |s|
          s.user = User.create!(
            email: "shipper#{i}@test.com",
            password: "password",
            first_name: "Test",
            last_name: "Shipper#{i}",
            user_type: "shipper"
          )
        end
      end
      
      # Create carriers
      carriers = 20.times.map do |i|
        Carrier.find_or_create_by(mc_number: "MC#{1000000 + i}") do |c|
          c.user = User.create!(
            email: "carrier#{i}@test.com",
            password: "password", 
            first_name: "Test",
            last_name: "Carrier#{i}",
            user_type: "carrier"
          )
          c.company_name = "Test Carrier #{i}"
          c.dot_number = "#{2000000 + i}"
          c.is_active = true
          c.is_verified = true
          c.equipment_types = ['dry_van', 'refrigerated'].to_json
          c.service_areas = ['TX', 'CA', 'FL', 'NY'].to_json
          c.insurance_amount = 1000000
          c.insurance_expiry = 1.year.from_now
        end
      end
      
      # Create vehicles
      carriers.each do |carrier|
        2.times do |v|
          Vehicle.find_or_create_by(
            carrier: carrier,
            vehicle_number: "#{carrier.company_name}-#{v + 1}"
          ) do |vehicle|
            vehicle.vin = "1HGCM#{rand(10000000..99999999)}#{rand(100000..999999)}"
            vehicle.make = "Freightliner"
            vehicle.model = "Cascadia"
            vehicle.year = rand(2018..2024)
            vehicle.equipment_type = ['dry_van', 'refrigerated'].sample
            vehicle.capacity_weight = rand(40000..80000)
            vehicle.status = 'active'
          end
        end
      end
      
      # Create loads
      200.times do |i|
        Load.find_or_create_by(
          shipper: shippers.sample,
          reference_number: "LOAD#{Date.current.strftime('%Y%m%d')}-#{i + 1}"
        ) do |load|
          load.commodity = "Test Commodity #{i}"
          load.weight = rand(10000..50000)
          load.equipment_type = ['dry_van', 'refrigerated'].sample
          load.pickup_city = "Houston"
          load.pickup_state = "TX"
          load.pickup_postal_code = "77001"
          load.pickup_address_line1 = "123 Test St"
          load.pickup_date = rand(1..30).days.from_now
          load.delivery_city = "Los Angeles"
          load.delivery_state = "CA" 
          load.delivery_postal_code = "90001"
          load.delivery_address_line1 = "456 Test Ave"
          load.delivery_date = load.pickup_date + rand(1..5).days
          load.rate = rand(1000..5000)
          load.status = 'posted'
          load.expires_at = 3.days.from_now
        end
      end
      
      puts "Benchmark data created successfully."
    end
    
    def benchmark_load_search
      carrier = Carrier.active.verified.first
      return puts "No carriers available for benchmarking" unless carrier
      
      # Benchmark basic load search
      time = Benchmark.measure do
        service = LoadSearchService.new(carrier, { equipment_type: 'dry_van' })
        result = service.search
      end
      puts "Basic load search: #{(time.real * 1000).round(2)}ms"
      
      # Benchmark with geographic filtering
      carrier.update!(latitude: 29.7604, longitude: -95.3698) # Houston coordinates
      time = Benchmark.measure do
        service = LoadSearchService.new(carrier, { max_distance: 100 })
        result = service.search
      end
      puts "Geographic load search: #{(time.real * 1000).round(2)}ms"
    end
    
    def benchmark_carrier_matching
      load = Load.where(status: 'posted').first
      return puts "No loads available for benchmarking" unless load
      
      # Benchmark basic carrier matching
      time = Benchmark.measure do
        service = MatchingAlgorithmService.new(load, { limit: 10 })
        result = service.find_eligible_carriers
      end
      puts "Basic carrier matching: #{(time.real * 1000).round(2)}ms"
      
      # Benchmark with complex filtering
      time = Benchmark.measure do
        service = MatchingAlgorithmService.new(load, { 
          limit: 5,
          verified_only: true,
          min_safety_rating: 3.0,
          max_distance_to_pickup: 200
        })
        result = service.find_eligible_carriers
      end
      puts "Complex carrier matching: #{(time.real * 1000).round(2)}ms"
    end
    
    def benchmark_geographic_queries
      # Benchmark raw geographic queries
      time = Benchmark.measure do
        Load.where(
          "3959 * acos(cos(radians(?)) * cos(radians(pickup_latitude)) * 
           cos(radians(pickup_longitude) - radians(?)) + 
           sin(radians(?)) * sin(radians(pickup_latitude))) <= ?",
          29.7604, -95.3698, 29.7604, 100
        ).where.not(pickup_latitude: nil, pickup_longitude: nil).limit(20).to_a
      end
      puts "Geographic distance query: #{(time.real * 1000).round(2)}ms"
    end
  end
end