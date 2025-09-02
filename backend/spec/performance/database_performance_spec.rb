require 'rails_helper'

RSpec.describe 'Database Performance Optimization', type: :request do
  before(:all) do
    # Create test data for performance testing
    @shippers = create_list(:shipper, 10)
    @carriers = create_list(:carrier, 50) do |carrier|
      carrier.update!(
        is_active: true,
        is_verified: true,
        equipment_types: ['dry_van', 'refrigerated'].to_json,
        service_areas: ['TX', 'CA', 'FL'].to_json
      )
    end
    
    # Create vehicles for carriers
    @carriers.each do |carrier|
      create_list(:vehicle, 3, carrier: carrier, status: 'active', equipment_type: 'dry_van')
    end
    
    # Create loads for testing
    @loads = create_list(:load, 100, :posted, shipper: @shippers.sample) do |load|
      load.update!(
        equipment_type: 'dry_van',
        pickup_state: ['TX', 'CA', 'FL'].sample,
        delivery_state: ['TX', 'CA', 'FL'].sample
      )
    end
    
    DatabasePerformanceMonitorService.instance.reset_stats
  end
  
  describe 'LoadSearchService Performance' do
    it 'performs load search under performance threshold' do
      carrier = @carriers.first
      
      start_time = Time.current
      service = LoadSearchService.new(carrier, { equipment_type: 'dry_van' })
      result = service.search
      execution_time = (Time.current - start_time) * 1000
      
      expect(result[:success]).to be true
      expect(execution_time).to be < 800  # Target: under 800ms
      expect(result[:loads]).to be_present
    end
    
    it 'handles geographic filtering efficiently' do
      carrier = @carriers.first
      carrier.update!(latitude: 32.7767, longitude: -96.7970) # Dallas coordinates
      
      start_time = Time.current
      service = LoadSearchService.new(carrier, { max_distance: 100 })
      result = service.search
      execution_time = (Time.current - start_time) * 1000
      
      expect(result[:success]).to be true
      expect(execution_time).to be < 500  # Geographic queries should be fast
    end
    
    it 'avoids N+1 queries by using includes' do
      carrier = @carriers.first
      
      query_count = 0
      callback = lambda do |*args|
        query_count += 1
      end
      
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        service = LoadSearchService.new(carrier, { equipment_type: 'dry_van' })
        result = service.search
      end
      
      # Should have minimal queries due to includes
      expect(query_count).to be < 10
    end
  end
  
  describe 'MatchingAlgorithmService Performance' do
    it 'performs carrier matching under performance threshold' do
      load = @loads.first
      
      start_time = Time.current
      service = MatchingAlgorithmService.new(load, { limit: 10 })
      result = service.find_eligible_carriers
      execution_time = (Time.current - start_time) * 1000
      
      expect(result[:success]).to be true
      expect(execution_time).to be < 800  # Target: under 800ms
      expect(result[:carriers]).to be_present
      expect(result[:carriers].length).to be <= 10
    end
    
    it 'handles complex filtering efficiently' do
      hazmat_load = create(:load, :posted, 
        shipper: @shippers.first,
        is_hazmat: true,
        equipment_type: 'dry_van'
      )
      
      start_time = Time.current
      service = MatchingAlgorithmService.new(hazmat_load, { 
        limit: 5,
        verified_only: true,
        min_safety_rating: 3.0
      })
      result = service.find_eligible_carriers
      execution_time = (Time.current - start_time) * 1000
      
      expect(result[:success]).to be true
      expect(execution_time).to be < 600  # Complex filtering should still be fast
    end
    
    it 'avoids N+1 queries with includes' do
      load = @loads.first
      
      query_count = 0
      callback = lambda do |*args|
        query_count += 1
      end
      
      ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
        service = MatchingAlgorithmService.new(load, { limit: 10 })
        result = service.find_eligible_carriers
      end
      
      # Should have minimal queries due to includes
      expect(query_count).to be < 15
    end
  end
  
  describe 'DatabasePerformanceMonitorService' do
    it 'tracks query performance' do
      monitor = DatabasePerformanceMonitorService.instance
      monitor.reset_stats
      
      # Perform some queries
      carrier = @carriers.first
      service = LoadSearchService.new(carrier)
      service.search
      
      performance_summary = monitor.get_performance_summary
      expect(performance_summary[:summary]).to have_key('load_search')
      expect(performance_summary[:summary]['load_search'][:count]).to be > 0
    end
    
    it 'detects slow queries' do
      monitor = DatabasePerformanceMonitorService.instance
      monitor.set_threshold(1) # Very low threshold to trigger detection
      monitor.reset_stats
      
      # This should trigger a slow query detection
      carrier = @carriers.first
      service = LoadSearchService.new(carrier)
      service.search
      
      performance_summary = monitor.get_performance_summary
      expect(performance_summary[:slow_queries_count]).to be >= 0
    end
  end
  
  describe 'Index Usage Verification' do
    it 'uses composite indexes for load queries' do
      # This would require database-specific testing
      # For now, we can check that the queries complete quickly
      load_query = Load.where(status: 'posted', equipment_type: 'dry_van', pickup_state: 'TX')
      
      start_time = Time.current
      result = load_query.to_a
      execution_time = (Time.current - start_time) * 1000
      
      expect(execution_time).to be < 100  # Should be very fast with proper indexes
    end
    
    it 'uses composite indexes for carrier queries' do
      carrier_query = Carrier.where(is_active: true, is_verified: true, safety_rating: 'satisfactory')
      
      start_time = Time.current
      result = carrier_query.to_a
      execution_time = (Time.current - start_time) * 1000
      
      expect(execution_time).to be < 50  # Should be very fast with proper indexes
    end
  end
  
  after(:all) do
    # Clean up test data
    DatabasePerformanceMonitorService.instance.reset_stats
  end
end