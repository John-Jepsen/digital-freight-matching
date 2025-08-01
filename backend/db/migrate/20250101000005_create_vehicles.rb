class CreateVehicles < ActiveRecord::Migration[8.0]
  def change
    create_table :vehicles do |t|
      t.references :carrier, null: false, foreign_key: true
      t.references :driver, null: true, foreign_key: true
      t.string :vehicle_number, null: false
      t.string :vin, null: false
      t.string :make, null: false
      t.string :model, null: false
      t.integer :year, null: false
      t.string :equipment_type, null: false
      t.decimal :capacity_weight, precision: 8, scale: 2
      t.decimal :capacity_volume, precision: 8, scale: 2
      t.decimal :length, precision: 6, scale: 2
      t.decimal :width, precision: 6, scale: 2
      t.decimal :height, precision: 6, scale: 2
      t.string :fuel_type, default: "diesel"
      t.decimal :mpg, precision: 4, scale: 2
      t.string :status, default: "active", null: false
      t.decimal :current_location_lat, precision: 10, scale: 6
      t.decimal :current_location_lng, precision: 10, scale: 6
      t.datetime :last_location_update
      t.date :maintenance_due_date
      t.date :inspection_due_date
      t.date :registration_expiry
      t.date :insurance_expiry
      t.boolean :is_temperature_controlled, default: false
      t.boolean :is_hazmat_certified, default: false
      t.boolean :is_team_capable, default: false

      t.timestamps
    end

    add_index :vehicles, [:carrier_id, :vehicle_number], unique: true
    add_index :vehicles, :vin, unique: true
    add_index :vehicles, :equipment_type
    add_index :vehicles, :status
    add_index :vehicles, :is_temperature_controlled
    add_index :vehicles, :is_hazmat_certified
    add_index :vehicles, [:current_location_lat, :current_location_lng]
    add_index :vehicles, :maintenance_due_date
    add_index :vehicles, :inspection_due_date
  end
end