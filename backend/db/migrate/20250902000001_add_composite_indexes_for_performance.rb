class AddCompositeIndexesForPerformance < ActiveRecord::Migration[7.1]
  def change
    # Composite indexes for common load search patterns
    # Used in LoadSearchService for filtering available loads
    add_index :loads, [:status, :equipment_type, :pickup_state], 
              name: 'idx_loads_status_equipment_pickup_state'
    
    add_index :loads, [:status, :equipment_type, :delivery_state], 
              name: 'idx_loads_status_equipment_delivery_state'
    
    add_index :loads, [:status, :pickup_date, :expires_at], 
              name: 'idx_loads_status_pickup_expires'
    
    # Composite indexes for carrier matching operations
    # Used in MatchingAlgorithmService for finding eligible carriers
    add_index :carriers, [:is_active, :is_verified, :safety_rating], 
              name: 'idx_carriers_active_verified_rating'
    
    # Composite indexes for vehicle availability and capability checks
    # Used for equipment type and capacity filtering
    add_index :vehicles, [:carrier_id, :equipment_type, :status], 
              name: 'idx_vehicles_carrier_equipment_status'
    
    add_index :vehicles, [:equipment_type, :capacity_weight, :status], 
              name: 'idx_vehicles_equipment_capacity_status'
    
    add_index :vehicles, [:status, :is_hazmat_certified, :is_temperature_controlled], 
              name: 'idx_vehicles_status_hazmat_temp'
    
    # Composite indexes for driver capability checks  
    add_index :drivers, [:carrier_id, :status, :is_hazmat_certified], 
              name: 'idx_drivers_carrier_status_hazmat'
    
    add_index :drivers, [:carrier_id, :status, :is_team_driver], 
              name: 'idx_drivers_carrier_status_team'
    
    # Composite indexes for match scoring and history
    add_index :matches, [:carrier_id, :status, :match_score], 
              name: 'idx_matches_carrier_status_score'
    
    add_index :matches, [:load_id, :status, :matched_at], 
              name: 'idx_matches_load_status_matched_at'
    
    # Performance index for geographic queries (when using PostGIS in future)
    # This will help with distance-based filtering
    add_index :loads, [:pickup_latitude, :pickup_longitude, :status], 
              name: 'idx_loads_pickup_location_status'
    
    add_index :carriers, [:latitude, :longitude, :is_active], 
              name: 'idx_carriers_location_active'
  end
end