class CreateLoads < ActiveRecord::Migration[8.0]
  def change
    create_table :loads do |t|
      t.references :shipper, null: false, foreign_key: true
      t.string :reference_number, null: false
      t.string :status, default: "posted", null: false
      t.string :load_type, null: false
      t.string :commodity, null: false
      t.text :description
      t.decimal :weight, precision: 8, scale: 2
      t.string :dimensions
      t.text :special_instructions

      # Pickup information
      t.string :pickup_address_line1, null: false
      t.string :pickup_address_line2
      t.string :pickup_city, null: false
      t.string :pickup_state, null: false
      t.string :pickup_postal_code, null: false
      t.string :pickup_country, default: "US"
      t.decimal :pickup_latitude, precision: 10, scale: 6
      t.decimal :pickup_longitude, precision: 10, scale: 6
      t.date :pickup_date, null: false
      t.time :pickup_time_window_start
      t.time :pickup_time_window_end
      t.string :pickup_contact_name
      t.string :pickup_contact_phone

      # Delivery information
      t.string :delivery_address_line1, null: false
      t.string :delivery_address_line2
      t.string :delivery_city, null: false
      t.string :delivery_state, null: false
      t.string :delivery_postal_code, null: false
      t.string :delivery_country, default: "US"
      t.decimal :delivery_latitude, precision: 10, scale: 6
      t.decimal :delivery_longitude, precision: 10, scale: 6
      t.date :delivery_date, null: false
      t.time :delivery_time_window_start
      t.time :delivery_time_window_end
      t.string :delivery_contact_name
      t.string :delivery_contact_phone

      # Equipment and pricing
      t.string :equipment_type, null: false
      t.decimal :rate, precision: 10, scale: 2, null: false
      t.string :rate_type, default: "flat", null: false
      t.decimal :mileage, precision: 8, scale: 2
      t.decimal :estimated_distance, precision: 8, scale: 2
      t.decimal :fuel_surcharge, precision: 6, scale: 2, default: 0.0
      t.decimal :accessorial_charges, precision: 8, scale: 2, default: 0.0
      t.decimal :total_rate, precision: 10, scale: 2
      t.string :currency, default: "USD"
      t.integer :payment_terms, default: 30

      # Special requirements
      t.boolean :requires_tracking, default: true
      t.boolean :requires_signature, default: false
      t.boolean :is_hazmat, default: false
      t.boolean :is_expedited, default: false
      t.boolean :is_team_driver, default: false
      t.boolean :temperature_controlled, default: false
      t.integer :temperature_min
      t.integer :temperature_max

      # Timestamps
      t.datetime :posted_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :loads, [:shipper_id, :reference_number], unique: true
    add_index :loads, :status
    add_index :loads, :equipment_type
    add_index :loads, :pickup_state
    add_index :loads, :delivery_state
    add_index :loads, :pickup_date
    add_index :loads, :delivery_date
    add_index :loads, :is_expedited
    add_index :loads, :is_hazmat
    add_index :loads, :temperature_controlled
    add_index :loads, [:pickup_latitude, :pickup_longitude]
    add_index :loads, [:delivery_latitude, :delivery_longitude]
    add_index :loads, :posted_at
    add_index :loads, :expires_at
  end
end