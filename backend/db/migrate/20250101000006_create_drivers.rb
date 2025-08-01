class CreateDrivers < ActiveRecord::Migration[8.0]
  def change
    create_table :drivers do |t|
      t.references :user, null: true, foreign_key: true
      t.references :carrier, null: false, foreign_key: true
      t.references :vehicle, null: true, foreign_key: true
      t.string :driver_number, null: false
      t.string :first_name, null: false
      t.string :last_name, null: false
      t.string :phone
      t.string :email
      t.string :license_number, null: false
      t.string :license_state, null: false
      t.date :license_expiry, null: false
      t.string :cdl_class, null: false
      t.string :cdl_endorsements
      t.date :medical_cert_expiry, null: false
      t.string :status, default: "available", null: false
      t.date :hire_date
      t.date :termination_date
      t.boolean :is_team_driver, default: false
      t.boolean :is_hazmat_certified, default: false
      t.boolean :is_owner_operator, default: false
      t.string :emergency_contact_name
      t.string :emergency_contact_phone
      t.string :address_line1
      t.string :address_line2
      t.string :city
      t.string :state
      t.string :postal_code
      t.string :country, default: "US"

      t.timestamps
    end

    add_index :drivers, [:carrier_id, :driver_number], unique: true
    add_index :drivers, [:license_number, :license_state], unique: true
    add_index :drivers, :status
    add_index :drivers, :is_hazmat_certified
    add_index :drivers, :is_team_driver
    add_index :drivers, :license_expiry
    add_index :drivers, :medical_cert_expiry
  end
end