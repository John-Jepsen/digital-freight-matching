#!/usr/bin/env ruby
# Database Performance Verification Script
# This script validates our database optimizations without requiring full Rails setup

require 'pg'
require 'json'

class DatabaseOptimizationValidator
  def initialize
    @db_config = {
      host: ENV['DB_HOST'] || 'localhost',
      port: ENV['DB_PORT'] || 5432,
      dbname: ENV['DB_NAME'] || 'freight_matching',
      user: ENV['DB_USER'] || 'freight_user',
      password: ENV['DB_PASSWORD'] || 'freight_pass_changeme'
    }
  end
  
  def validate_all
    puts "🔍 Database Performance Optimization Validator"
    puts "=" * 50
    
    begin
      connect_to_db
      
      puts "\n📊 Checking composite indexes..."
      check_composite_indexes
      
      puts "\n⚡ Testing query performance patterns..."
      test_query_patterns
      
      puts "\n🎯 Performance validation completed!"
      
    rescue PG::Error => e
      puts "❌ Database connection failed: #{e.message}"
      puts "ℹ️  This is expected if the database is not set up yet."
      puts "   Run: docker compose up -d postgres"
      puts "   Then: bundle exec rails db:create db:migrate"
      return false
    rescue => e
      puts "❌ Validation failed: #{e.message}"
      return false
    ensure
      @conn&.close
    end
    
    true
  end
  
  private
  
  def connect_to_db
    @conn = PG.connect(@db_config)
    puts "✅ Connected to PostgreSQL database"
  end
  
  def check_composite_indexes
    expected_indexes = [
      'idx_loads_status_equipment_pickup_state',
      'idx_loads_status_equipment_delivery_state', 
      'idx_loads_status_pickup_expires',
      'idx_carriers_active_verified_rating',
      'idx_vehicles_carrier_equipment_status',
      'idx_vehicles_equipment_capacity_status',
      'idx_drivers_carrier_status_hazmat',
      'idx_matches_carrier_status_score'
    ]
    
    # Query to get all indexes
    result = @conn.exec(<<~SQL)
      SELECT indexname, tablename, indexdef
      FROM pg_indexes 
      WHERE schemaname = 'public'
      AND indexname IN (#{expected_indexes.map { |idx| "'#{idx}'" }.join(', ')})
      ORDER BY tablename, indexname;
    SQL
    
    found_indexes = result.map { |row| row['indexname'] }
    
    expected_indexes.each do |expected|
      if found_indexes.include?(expected)
        puts "  ✅ #{expected}"
      else
        puts "  ❌ #{expected} - MISSING"
      end
    end
    
    puts "\n  📈 Index statistics:"
    
    # Get index usage stats
    stats_result = @conn.exec(<<~SQL)
      SELECT 
        schemaname,
        tablename,
        indexname,
        idx_scan as scans,
        idx_tup_read as tuples_read
      FROM pg_stat_user_indexes
      WHERE schemaname = 'public'
      AND indexname IN (#{expected_indexes.map { |idx| "'#{idx}'" }.join(', ')})
      ORDER BY idx_scan DESC;
    SQL
    
    if stats_result.any?
      stats_result.each do |row|
        puts "    #{row['indexname']}: #{row['scans']} scans, #{row['tuples_read']} tuples read"
      end
    else
      puts "    No usage statistics available (expected for new indexes)"
    end
  end
  
  def test_query_patterns
    test_cases = [
      {
        name: "Load search by status, equipment, and location",
        sql: <<~SQL
          EXPLAIN ANALYZE 
          SELECT COUNT(*) 
          FROM loads 
          WHERE status = 'posted' 
          AND equipment_type = 'dry_van' 
          AND pickup_state = 'TX'
        SQL
      },
      {
        name: "Carrier filtering by activity and verification",
        sql: <<~SQL
          EXPLAIN ANALYZE 
          SELECT COUNT(*) 
          FROM carriers 
          WHERE is_active = true 
          AND is_verified = true 
          AND safety_rating = 'satisfactory'
        SQL
      },
      {
        name: "Vehicle capability matching",
        sql: <<~SQL
          EXPLAIN ANALYZE 
          SELECT COUNT(*) 
          FROM vehicles v
          JOIN carriers c ON v.carrier_id = c.id
          WHERE v.equipment_type = 'dry_van'
          AND v.status = 'active'
          AND c.is_active = true
        SQL
      }
    ]
    
    test_cases.each do |test|
      puts "\n  🧪 #{test[:name]}:"
      
      begin
        result = @conn.exec(test[:sql])
        
        # Extract execution time from EXPLAIN ANALYZE
        execution_time = nil
        query_plan_lines = []
        
        result.each do |row|
          line = row['QUERY PLAN']
          query_plan_lines << line
          
          # Look for execution time
          if match = line.match(/Execution Time: ([\d.]+) ms/)
            execution_time = match[1].to_f
          end
        end
        
        if execution_time
          if execution_time < 100
            puts "    ✅ Execution time: #{execution_time}ms (excellent)"
          elsif execution_time < 500
            puts "    ⚡ Execution time: #{execution_time}ms (good)"
          elsif execution_time < 1000
            puts "    ⚠️  Execution time: #{execution_time}ms (acceptable)"
          else
            puts "    ❌ Execution time: #{execution_time}ms (slow)"
          end
        else
          puts "    ℹ️  Could not extract execution time"
        end
        
        # Check if index is being used (look for Index Scan instead of Seq Scan)
        using_index = query_plan_lines.any? { |line| line.include?('Index Scan') || line.include?('Index Only Scan') }
        if using_index
          puts "    ✅ Using index scan"
        else
          seq_scan = query_plan_lines.any? { |line| line.include?('Seq Scan') }
          if seq_scan
            puts "    ⚠️  Using sequential scan (may need more data for optimizer)"
          else
            puts "    ℹ️  Index usage unclear"
          end
        end
        
      rescue PG::Error => e
        puts "    ❌ Query failed: #{e.message}"
      end
    end
  end
end

# Run the validator
if __FILE__ == $0
  validator = DatabaseOptimizationValidator.new
  success = validator.validate_all
  exit(success ? 0 : 1)
end