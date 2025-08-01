class CreateRoutes < ActiveRecord::Migration[8.0]
  def change
    create_table :routes do |t|
      t.references :match, null: false, foreign_key: true
      t.decimal :origin_latitude, precision: 10, scale: 6, null: false
      t.decimal :origin_longitude, precision: 10, scale: 6, null: false
      t.decimal :destination_latitude, precision: 10, scale: 6, null: false
      t.decimal :destination_longitude, precision: 10, scale: 6, null: false
      t.decimal :distance_miles, precision: 8, scale: 2
      t.integer :estimated_duration # in minutes
      t.text :route_geometry # Encoded polyline
      t.text :waypoints # JSON array of waypoints
      t.text :route_instructions # JSON array of turn-by-turn directions
      t.string :traffic_conditions
      t.decimal :toll_cost, precision: 8, scale: 2
      t.decimal :fuel_cost, precision: 8, scale: 2
      t.decimal :total_cost, precision: 10, scale: 2
      t.string :optimization_type, default: 'fastest'
      t.boolean :avoid_highways, default: false
      t.boolean :avoid_tolls, default: false
      t.text :vehicle_restrictions # JSON for truck restrictions
      t.datetime :calculated_at
      t.datetime :expires_at
      t.boolean :is_optimized, default: false

      t.timestamps
    end

    add_index :routes, :match_id
    add_index :routes, :optimization_type
    add_index :routes, :expires_at
    add_index :routes, :calculated_at
    add_index :routes, [:origin_latitude, :origin_longitude]
    add_index :routes, [:destination_latitude, :destination_longitude]
  end
end