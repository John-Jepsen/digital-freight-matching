class CreateCarriers < ActiveRecord::Migration[8.0]
  def change
    create_table :carriers do |t|
      t.references :user, null: false, foreign_key: true
      t.string :company_name, null: false
      t.text :company_description
      t.string :mc_number, null: false
      t.string :dot_number, null: false
      t.string :scac_code
      t.string :address_line1
      t.string :address_line2
      t.string :city
      t.string :state
      t.string :postal_code
      t.string :country, default: "US"
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.string :phone
      t.string :website
      t.integer :fleet_size, default: 1
      t.text :equipment_types
      t.text :service_areas
      t.decimal :insurance_amount, precision: 12, scale: 2
      t.date :insurance_expiry
      t.string :operating_authority
      t.string :safety_rating, default: "satisfactory"
      t.boolean :is_verified, default: false
      t.boolean :is_active, default: true
      t.text :preferred_lanes

      t.timestamps
    end

    add_index :carriers, :company_name
    add_index :carriers, :mc_number, unique: true
    add_index :carriers, :dot_number, unique: true
    add_index :carriers, :scac_code, unique: true
    add_index :carriers, :safety_rating
    add_index :carriers, :is_verified
    add_index :carriers, :is_active
    add_index :carriers, [:latitude, :longitude]
  end
end