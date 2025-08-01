class CreateShippers < ActiveRecord::Migration[8.0]
  def change
    create_table :shippers do |t|
      t.references :user, null: false, foreign_key: true
      t.string :company_name, null: false
      t.text :company_description
      t.string :industry
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
      t.string :tax_id
      t.string :dot_number
      t.decimal :credit_limit, precision: 10, scale: 2, default: 0.0
      t.integer :payment_terms, default: 30
      t.text :preferred_carriers
      t.integer :shipping_volume_monthly, default: 0

      t.timestamps
    end

    add_index :shippers, :company_name
    add_index :shippers, :industry
    add_index :shippers, :tax_id, unique: true
    add_index :shippers, :dot_number, unique: true
    add_index :shippers, [:latitude, :longitude]
  end
end