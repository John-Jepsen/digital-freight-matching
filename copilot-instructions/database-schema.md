# Database Schema & Data Management

## 🗄️ Database Architecture Overview

**System**: PostgreSQL 16 with PostGIS extensions  
**ORM**: ActiveRecord (Rails)  
**Security**: Row-Level Security (RLS), encrypted connections  
**Extensions**: PostGIS for geographic data, JSONB for flexible storage  

## 📊 Core Entity Relationships

### Primary Entities Structure
```
User (authentication hub)
├── ShipperProfile (freight shippers)
│   └── Loads (freight postings)
│       ├── LoadRequirements (equipment/special needs)
│       ├── CargoDetails (freight specifications)
│       └── Matches (carrier matches)
└── CarrierProfile (transportation providers)
    ├── Vehicles (fleet management)
    ├── Drivers (personnel)
    └── Matches (accepted loads)
        └── Shipments (active tracking)
            └── TrackingEvents (location history)
```

### Critical Business Relationships
```sql
-- One shipper can post multiple loads
ShipperProfile 1:N Load

-- One load can have multiple carrier matches
Load 1:N Match

-- One carrier can have multiple matches
CarrierProfile 1:N Match

-- One accepted match becomes one shipment
Match 1:1 Shipment

-- One shipment has many tracking events
Shipment 1:N TrackingEvent
```

## 🏗️ Schema Design Patterns

### User Management System
```ruby
# Central authentication table
class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :encrypted_password, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :phone_number
      t.string :user_type, null: false # 'shipper', 'carrier', 'admin'
      t.boolean :active, default: true
      t.timestamps
    end
    
    add_index :users, :email, unique: true
    add_index :users, :user_type
    add_index :users, :active
    add_index :users, :created_at
  end
end

# Shipper-specific business data
class CreateShipperProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :shipper_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :company_name, null: false
      t.string :business_type # 'manufacturer', 'distributor', 'retailer', 'logistics'
      t.string :payment_terms # 'net_30', 'net_15', 'quick_pay', 'cash_on_delivery'
      t.decimal :credit_rating, precision: 3, scale: 2
      t.jsonb :preferences, default: {}
      t.timestamps
    end
    
    add_index :shipper_profiles, :user_id, unique: true
    add_index :shipper_profiles, :company_name
    add_index :shipper_profiles, :business_type
  end
end

# Carrier business profiles
class CreateCarrierProfiles < ActiveRecord::Migration[8.0]
  def change
    create_table :carrier_profiles do |t|
      t.references :user, null: false, foreign_key: true
      t.string :company_name, null: false
      t.string :dot_number, null: false # DOT compliance requirement
      t.string :mc_number, null: false  # Motor carrier authority
      t.text :insurance_info
      t.string :status, default: 'active' # 'active', 'inactive', 'suspended'
      t.decimal :rating, precision: 3, scale: 2, default: 0
      t.integer :total_deliveries, default: 0
      t.jsonb :equipment_types, default: []
      t.decimal :latitude, precision: 10, scale: 8
      t.decimal :longitude, precision: 11, scale: 8
      t.timestamps
    end
    
    add_index :carrier_profiles, :user_id, unique: true
    add_index :carrier_profiles, :dot_number, unique: true
    add_index :carrier_profiles, :mc_number, unique: true
    add_index :carrier_profiles, :status
    add_index :carrier_profiles, :rating
    add_index :carrier_profiles, [:latitude, :longitude]
  end
end
```

### Load Management Schema
```ruby
class CreateLoads < ActiveRecord::Migration[8.0]
  def change
    create_table :loads do |t|
      t.references :shipper, null: false, foreign_key: { to_table: :shipper_profiles }
      t.string :pickup_location, null: false
      t.string :delivery_location, null: false
      t.datetime :pickup_datetime, null: false
      t.datetime :delivery_datetime, null: false
      t.decimal :weight, precision: 10, scale: 2
      t.decimal :price, precision: 10, scale: 2, null: false
      t.text :description
      t.string :status, default: 'posted' # State machine values
      
      # Calculated geographic data
      t.decimal :pickup_lat, precision: 10, scale: 8
      t.decimal :pickup_lng, precision: 11, scale: 8
      t.decimal :delivery_lat, precision: 10, scale: 8
      t.decimal :delivery_lng, precision: 11, scale: 8
      t.decimal :distance_miles, precision: 8, scale: 2
      t.decimal :estimated_duration_hours, precision: 6, scale: 2
      
      # Search optimization
      t.tsvector :search_vector
      
      t.timestamps
    end
    
    # Performance-critical indexes
    add_index :loads, :status
    add_index :loads, [:status, :pickup_datetime]
    add_index :loads, :pickup_datetime
    add_index :loads, :delivery_datetime
    add_index :loads, :price
    add_index :loads, :weight
    add_index :loads, :distance_miles
    add_index :loads, [:pickup_lat, :pickup_lng]
    add_index :loads, [:delivery_lat, :delivery_lng]
    add_index :loads, :search_vector, using: :gin
    
    # Composite indexes for common queries
    add_index :loads, [:shipper_id, :status]
    add_index :loads, [:status, :price]
  end
end

# Specialized equipment requirements
class CreateLoadRequirements < ActiveRecord::Migration[8.0]
  def change
    create_table :load_requirements do |t|
      t.references :load, null: false, foreign_key: true
      t.string :equipment_type, null: false # 'dry_van', 'refrigerated', 'flatbed', 'hazmat'
      t.boolean :hazmat, default: false
      t.boolean :temperature_controlled, default: false
      t.decimal :min_temperature, precision: 5, scale: 2
      t.decimal :max_temperature, precision: 5, scale: 2
      t.text :special_handling
      t.string :certification_required
      t.timestamps
    end
    
    add_index :load_requirements, :load_id
    add_index :load_requirements, :equipment_type
    add_index :load_requirements, :hazmat
    add_index :load_requirements, :temperature_controlled
  end
end

# Detailed cargo information
class CreateCargoDetails < ActiveRecord::Migration[8.0]
  def change
    create_table :cargo_details do |t|
      t.references :load, null: false, foreign_key: true
      t.string :freight_class # LTL freight classifications
      t.string :nmfc_code     # National Motor Freight Classification
      t.integer :pieces
      t.string :packaging     # 'pallets', 'crates', 'drums', 'loose'
      t.jsonb :dimensions     # {length: 48, width: 40, height: 72} in inches
      t.decimal :value, precision: 12, scale: 2 # Cargo value for insurance
      t.timestamps
    end
    
    add_index :cargo_details, :load_id
    add_index :cargo_details, :freight_class
    add_index :cargo_details, :packaging
  end
end
```

### Matching & Operations Schema
```ruby
class CreateMatches < ActiveRecord::Migration[8.0]
  def change
    create_table :matches do |t|
      t.references :load, null: false, foreign_key: true
      t.references :carrier, null: false, foreign_key: { to_table: :carrier_profiles }
      t.string :status, default: 'pending' # 'pending', 'accepted', 'rejected', 'expired'
      t.decimal :match_score, precision: 5, scale: 2 # 0-100 algorithm score
      t.decimal :quoted_price, precision: 10, scale: 2
      t.text :notes
      t.datetime :matched_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.datetime :expires_at
      t.timestamps
    end
    
    # Prevent duplicate matches
    add_index :matches, [:load_id, :carrier_id], unique: true
    add_index :matches, :status
    add_index :matches, [:match_score], order: { match_score: :desc }
    add_index :matches, :expires_at
    add_index :matches, :matched_at
  end
end

class CreateRoutes < ActiveRecord::Migration[8.0]
  def change
    create_table :routes do |t|
      t.references :match, null: false, foreign_key: true
      t.string :origin_location, null: false
      t.string :destination_location, null: false
      t.jsonb :waypoints, default: []
      t.decimal :distance_miles, precision: 8, scale: 2
      t.decimal :estimated_duration_hours, precision: 6, scale: 2
      t.decimal :fuel_cost, precision: 8, scale: 2
      t.decimal :toll_cost, precision: 8, scale: 2
      t.jsonb :route_data # Google Maps API response
      t.string :optimization_type # 'fastest', 'shortest', 'most_fuel_efficient'
      t.timestamps
    end
    
    add_index :routes, :match_id
    add_index :routes, :distance_miles
    add_index :routes, :estimated_duration_hours
  end
end
```

### Shipment Tracking Schema
```ruby
class CreateShipments < ActiveRecord::Migration[8.0]
  def change
    create_table :shipments do |t|
      t.references :match, null: false, foreign_key: true
      t.string :status, default: 'pending' # 'pending', 'in_transit', 'delivered', 'exception'
      t.datetime :pickup_confirmed_at
      t.datetime :delivery_confirmed_at
      
      # Real-time location tracking
      t.decimal :current_latitude, precision: 10, scale: 8
      t.decimal :current_longitude, precision: 11, scale: 8
      t.datetime :last_location_update
      
      # Delivery estimates
      t.datetime :estimated_delivery
      t.datetime :actual_delivery
      
      # Performance tracking
      t.decimal :progress_percentage, precision: 5, scale: 2, default: 0
      t.text :notes
      
      t.timestamps
    end
    
    add_index :shipments, :match_id, unique: true
    add_index :shipments, :status
    add_index :shipments, [:current_latitude, :current_longitude]
    add_index :shipments, :estimated_delivery
    add_index :shipments, :last_location_update
  end
end

class CreateTrackingEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :tracking_events do |t|
      t.references :shipment, null: false, foreign_key: true
      t.string :event_type, null: false # 'pickup_confirmed', 'in_transit', 'delivered', 'exception'
      t.string :location
      t.decimal :latitude, precision: 10, scale: 8
      t.decimal :longitude, precision: 11, scale: 8
      t.text :description
      t.datetime :occurred_at, default: -> { 'CURRENT_TIMESTAMP' }
      t.jsonb :metadata, default: {} # Additional event data
      t.timestamps null: false
    end
    
    add_index :tracking_events, :shipment_id
    add_index :tracking_events, [:shipment_id, :occurred_at], order: { occurred_at: :desc }
    add_index :tracking_events, :event_type
    add_index :tracking_events, :occurred_at
    add_index :tracking_events, [:latitude, :longitude]
  end
end
```

### Fleet Management Schema
```ruby
class CreateVehicles < ActiveRecord::Migration[8.0]
  def change
    create_table :vehicles do |t|
      t.references :carrier, null: false, foreign_key: { to_table: :carrier_profiles }
      t.string :vehicle_type, null: false # 'dry_van', 'refrigerated', 'flatbed', 'tank'
      t.string :make
      t.string :model
      t.integer :year
      t.string :vin, null: false
      t.string :license_plate
      t.decimal :capacity_weight, precision: 10, scale: 2 # Max weight in pounds
      t.decimal :capacity_volume, precision: 10, scale: 2 # Max volume in cubic feet
      t.jsonb :equipment_features, default: [] # ['gps_tracking', 'temperature_control', 'lift_gate']
      t.string :status, default: 'active' # 'active', 'maintenance', 'inactive'
      t.timestamps
    end
    
    add_index :vehicles, :carrier_id
    add_index :vehicles, :vin, unique: true
    add_index :vehicles, :vehicle_type
    add_index :vehicles, :status
    add_index :vehicles, [:carrier_id, :status]
  end
end

class CreateDrivers < ActiveRecord::Migration[8.0]
  def change
    create_table :drivers do |t|
      t.references :carrier, null: false, foreign_key: { to_table: :carrier_profiles }
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :license_number, null: false
      t.string :license_class # 'CDL-A', 'CDL-B', 'CDL-C'
      t.date :license_expiry
      t.string :phone_number
      t.string :email
      t.jsonb :certifications, default: [] # ['hazmat', 'passenger', 'school_bus']
      t.string :status, default: 'active' # 'active', 'inactive', 'suspended'
      t.decimal :rating, precision: 3, scale: 2, default: 0
      t.timestamps
    end
    
    add_index :drivers, :carrier_id
    add_index :drivers, :license_number, unique: true
    add_index :drivers, :status
    add_index :drivers, :license_expiry
    add_index :drivers, [:carrier_id, :status]
  end
end
```

## 🔍 Query Optimization Strategies

### Geographic Search Optimization
```sql
-- Efficient radius-based load search
CREATE OR REPLACE FUNCTION loads_near_location(
  search_lat DECIMAL(10,8),
  search_lng DECIMAL(11,8),
  radius_miles INTEGER DEFAULT 100
)
RETURNS TABLE(
  load_id INTEGER,
  distance_miles DECIMAL(8,2)
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    l.id,
    (3959 * acos(
      cos(radians(search_lat)) * 
      cos(radians(l.pickup_lat)) * 
      cos(radians(l.pickup_lng) - radians(search_lng)) + 
      sin(radians(search_lat)) * 
      sin(radians(l.pickup_lat))
    ))::DECIMAL(8,2) as distance
  FROM loads l
  WHERE l.status = 'posted'
    AND (3959 * acos(
      cos(radians(search_lat)) * 
      cos(radians(l.pickup_lat)) * 
      cos(radians(l.pickup_lng) - radians(search_lng)) + 
      sin(radians(search_lat)) * 
      sin(radians(l.pickup_lat))
    )) <= radius_miles
  ORDER BY distance;
END;
$$ LANGUAGE plpgsql;

-- Usage in Rails
# Load.connection.execute(
#   "SELECT * FROM loads_near_location(33.7490, -84.3880, 50)"
# )
```

### Full-Text Search Setup
```sql
-- Search vector update function
CREATE OR REPLACE FUNCTION update_loads_search_vector()
RETURNS trigger AS $$
BEGIN
  NEW.search_vector := 
    setweight(to_tsvector('english', COALESCE(NEW.description, '')), 'A') ||
    setweight(to_tsvector('english', COALESCE(NEW.pickup_location, '')), 'B') ||
    setweight(to_tsvector('english', COALESCE(NEW.delivery_location, '')), 'B');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to automatically update search vector
CREATE TRIGGER loads_search_vector_update
  BEFORE INSERT OR UPDATE ON loads
  FOR EACH ROW EXECUTE FUNCTION update_loads_search_vector();

-- Efficient text search query
SELECT l.*, ts_rank(l.search_vector, plainto_tsquery('english', 'electronics atlanta')) as rank
FROM loads l
WHERE l.search_vector @@ plainto_tsquery('english', 'electronics atlanta')
  AND l.status = 'posted'
ORDER BY rank DESC, l.created_at DESC;
```

### Performance Monitoring Queries
```sql
-- Load performance analytics
CREATE VIEW load_performance_summary AS
SELECT 
  DATE_TRUNC('month', created_at) as month,
  COUNT(*) as total_loads,
  COUNT(*) FILTER (WHERE status = 'delivered') as completed_loads,
  AVG(price) as avg_price,
  AVG(distance_miles) as avg_distance,
  AVG(price / NULLIF(distance_miles, 0)) as avg_price_per_mile
FROM loads
GROUP BY DATE_TRUNC('month', created_at)
ORDER BY month DESC;

-- Carrier performance metrics
CREATE VIEW carrier_performance_metrics AS
SELECT 
  cp.id,
  cp.company_name,
  COUNT(m.id) as total_matches,
  COUNT(m.id) FILTER (WHERE m.status = 'accepted') as accepted_matches,
  AVG(m.match_score) as avg_match_score,
  COUNT(s.id) FILTER (WHERE s.status = 'delivered') as completed_deliveries,
  AVG(EXTRACT(EPOCH FROM (s.actual_delivery - s.pickup_confirmed_at))/3600) as avg_delivery_hours
FROM carrier_profiles cp
LEFT JOIN matches m ON cp.id = m.carrier_id
LEFT JOIN shipments s ON m.id = s.match_id
GROUP BY cp.id, cp.company_name;
```

## 🔐 Row-Level Security Implementation

### Security Policies
```sql
-- Enable RLS on sensitive tables
ALTER TABLE loads ENABLE ROW LEVEL SECURITY;
ALTER TABLE matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipments ENABLE ROW LEVEL SECURITY;

-- Load access policy
CREATE POLICY loads_access_policy ON loads
  FOR ALL TO authenticated_user
  USING (
    -- Shippers see their own loads
    shipper_id = current_shipper_id() 
    OR 
    -- Carriers see available loads or loads they've matched
    (status = 'posted' AND current_user_role() = 'carrier')
    OR
    id IN (
      SELECT load_id FROM matches 
      WHERE carrier_id = current_carrier_id()
    )
    OR
    -- Admins see everything
    current_user_role() = 'admin'
  );

-- Match access policy  
CREATE POLICY matches_access_policy ON matches
  FOR ALL TO authenticated_user
  USING (
    -- Load owner can see all matches for their load
    load_id IN (
      SELECT id FROM loads WHERE shipper_id = current_shipper_id()
    )
    OR
    -- Carriers see their own matches
    carrier_id = current_carrier_id()
    OR
    -- Admins see everything
    current_user_role() = 'admin'
  );

-- Helper functions for RLS
CREATE OR REPLACE FUNCTION current_user_id()
RETURNS INTEGER AS $$
  SELECT NULLIF(current_setting('app.current_user_id', true), '')::INTEGER;
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION current_user_role()
RETURNS TEXT AS $$
  SELECT NULLIF(current_setting('app.current_user_role', true), '');
$$ LANGUAGE SQL STABLE;

CREATE OR REPLACE FUNCTION current_shipper_id()
RETURNS INTEGER AS $$
  SELECT NULLIF(current_setting('app.current_shipper_id', true), '')::INTEGER;
$$ LANGUAGE SQL STABLE;
```

## 📊 Data Validation & Constraints

### Business Logic Constraints
```sql
-- Price must be reasonable (between $50 and $50,000)
ALTER TABLE loads ADD CONSTRAINT reasonable_price_range 
  CHECK (price >= 50 AND price <= 50000);

-- Weight must be within legal limits (max 80,000 lbs)
ALTER TABLE loads ADD CONSTRAINT legal_weight_limit
  CHECK (weight IS NULL OR (weight > 0 AND weight <= 80000));

-- Pickup must be before delivery
ALTER TABLE loads ADD CONSTRAINT pickup_before_delivery
  CHECK (pickup_datetime < delivery_datetime);

-- Delivery must be in the future (for new loads)
ALTER TABLE loads ADD CONSTRAINT delivery_in_future
  CHECK (delivery_datetime > pickup_datetime);

-- DOT number format validation
ALTER TABLE carrier_profiles ADD CONSTRAINT valid_dot_number_format
  CHECK (dot_number ~ '^[0-9]{1,8}$');

-- Rating must be between 0 and 5
ALTER TABLE carrier_profiles ADD CONSTRAINT valid_rating_range
  CHECK (rating >= 0 AND rating <= 5);

-- Progress percentage validation
ALTER TABLE shipments ADD CONSTRAINT valid_progress_percentage
  CHECK (progress_percentage >= 0 AND progress_percentage <= 100);
```

## 🗂️ Data Archival & Cleanup

### Automated Data Management
```sql
-- Archive completed loads older than 2 years
CREATE TABLE loads_archive (LIKE loads INCLUDING ALL);

-- Move old completed loads to archive
CREATE OR REPLACE FUNCTION archive_old_loads()
RETURNS INTEGER AS $$
DECLARE
  archived_count INTEGER;
BEGIN
  WITH archived_loads AS (
    DELETE FROM loads 
    WHERE status IN ('delivered', 'cancelled') 
      AND updated_at < CURRENT_DATE - INTERVAL '2 years'
    RETURNING *
  )
  INSERT INTO loads_archive 
  SELECT * FROM archived_loads;
  
  GET DIAGNOSTICS archived_count = ROW_COUNT;
  RETURN archived_count;
END;
$$ LANGUAGE plpgsql;

-- Clean up old tracking events (keep last 90 days)
CREATE OR REPLACE FUNCTION cleanup_old_tracking_events()
RETURNS INTEGER AS $$
DECLARE
  deleted_count INTEGER;
BEGIN
  DELETE FROM tracking_events 
  WHERE created_at < CURRENT_DATE - INTERVAL '90 days'
    AND shipment_id IN (
      SELECT id FROM shipments WHERE status = 'delivered'
    );
  
  GET DIAGNOSTICS deleted_count = ROW_COUNT;
  RETURN deleted_count;
END;
$$ LANGUAGE plpgsql;
```

*This database schema provides a robust foundation for freight matching operations while maintaining data integrity, performance, and security.*
