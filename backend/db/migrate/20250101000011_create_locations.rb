class CreateLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :locations do |t|
      t.string :name, null: false
      t.string :address_line1, null: false
      t.string :address_line2
      t.string :city, null: false
      t.string :state, null: false
      t.string :postal_code, null: false
      t.string :country, default: 'US'
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.string :location_type, null: false
      t.string :contact_name
      t.string :contact_phone
      t.string :contact_email
      t.text :hours_of_operation
      t.text :special_instructions
      t.string :facility_type
      t.string :dock_type
      t.text :equipment_available
      t.boolean :is_active, default: true
      t.string :timezone

      t.timestamps
    end

    add_index :locations, [:latitude, :longitude]
    add_index :locations, :location_type
    add_index :locations, :state
    add_index :locations, :is_active
    add_index :locations, [:city, :state]
  end
end