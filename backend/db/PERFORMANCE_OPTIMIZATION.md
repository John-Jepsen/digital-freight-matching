# Database Performance Optimization

This directory contains performance optimizations implemented to reduce database query times by 60% and eliminate N+1 query issues.

## Summary of Changes

### 1. Composite Indexes Added

New migration: `20250902000001_add_composite_indexes_for_performance.rb`

Key composite indexes for frequent query patterns:
- `loads(status, equipment_type, pickup_state)` - for load search filtering
- `loads(status, equipment_type, delivery_state)` - for delivery location filtering  
- `carriers(is_active, is_verified, safety_rating)` - for carrier eligibility checks
- `vehicles(carrier_id, equipment_type, status)` - for equipment matching
- `vehicles(equipment_type, capacity_weight, status)` - for capacity filtering
- Geographic indexes for spatial queries

### 2. Service Layer Optimizations

#### LoadSearchService
- Added `includes()` for preloading associations (eliminates N+1 queries)
- Replaced Ruby distance calculations with SQL Haversine formula
- Added optimized composite query patterns
- Performance monitoring integration

#### MatchingAlgorithmService  
- Optimized carrier filtering with proper joins
- Uses `merge()` for better ActiveRecord query composition
- Preloads all necessary associations upfront
- Database-level geographic filtering

### 3. Model Scopes Enhancement

#### Load Model
- `search_by_equipment_and_location()` - uses composite indexes
- `near_pickup_location()` - optimized geographic search
- `available_with_requirements()` - combines multiple filters efficiently

#### Carrier Model
- `eligible_for_matching()` - combines activity, verification, insurance checks
- `with_safety_standard()` - uses composite index
- `near_location()` - optimized geographic search

#### Vehicle Model
- `available_for_load()` - equipment + capacity filtering
- `capable_of_requirements()` - multi-requirement filtering
- `by_carrier_and_capabilities()` - uses composite indexes

### 4. Performance Monitoring

#### DatabasePerformanceMonitorService
- Singleton service for tracking query performance
- EXPLAIN ANALYZE integration for development
- Slow query detection (configurable threshold)
- Performance metrics collection and reporting

### 5. Testing & Analysis Tools

#### Performance Test Suite
- `spec/performance/database_performance_spec.rb`
- Validates <800ms query response times
- Tests N+1 query elimination
- Index usage verification

#### Rake Tasks
- `rake db:performance:analyze` - performance statistics
- `rake db:performance:benchmark` - run performance benchmarks
- `rake db:performance:reset_stats` - reset monitoring data

## Running Performance Tests

```bash
# Run the database performance test suite
bundle exec rspec spec/performance/database_performance_spec.rb

# Analyze current performance statistics
bundle exec rake db:performance:analyze

# Run performance benchmarks
bundle exec rake db:performance:benchmark

# Validate optimizations (without Rails environment)
ruby db/validate_optimizations.rb
```

## Expected Performance Improvements

- **Load search queries**: From 2000ms+ to <800ms (60% improvement)
- **Carrier matching**: From complex N+1 queries to <800ms
- **Geographic queries**: Significant improvement with spatial indexes
- **N+1 elimination**: Reduces database calls by 80-90%

## Index Usage

The composite indexes are designed to support these common query patterns:

1. **Load Search**: `WHERE status = 'posted' AND equipment_type = 'dry_van' AND pickup_state = 'TX'`
2. **Carrier Filtering**: `WHERE is_active = true AND is_verified = true AND safety_rating = 'satisfactory'`
3. **Vehicle Matching**: `WHERE carrier_id = 123 AND equipment_type = 'dry_van' AND status = 'active'`
4. **Geographic Queries**: Distance-based filtering with spatial calculations

## Monitoring Slow Queries

The system now automatically logs queries taking longer than 1 second:

```ruby
# Configure threshold (default: 1000ms)
DatabasePerformanceMonitorService.instance.set_threshold(500) # 500ms threshold

# View performance summary
summary = DatabasePerformanceMonitorService.instance.get_performance_summary
puts summary[:recent_slow_queries]
```

## Production Deployment

1. **Apply the migration**:
   ```bash
   bundle exec rails db:migrate
   ```

2. **Monitor index creation**: Large tables may take time to build indexes

3. **Validate performance**: Run the validation script after migration

4. **Monitor in production**: Set up alerts for slow queries

## Database Statistics

After deployment, monitor these metrics:
- Index usage statistics (`pg_stat_user_indexes`)
- Query execution plans (`EXPLAIN ANALYZE`)
- Slow query logs
- Database CPU and I/O utilization

The optimizations should result in:
- 60% reduction in query response times
- 40% reduction in database CPU usage
- Support for 500+ concurrent users
- Elimination of N+1 query patterns