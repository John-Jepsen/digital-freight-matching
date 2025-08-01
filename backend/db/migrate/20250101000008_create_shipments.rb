class CreateShipments < ActiveRecord::Migration[8.0]
  def change
    create_table :shipments do |t|
      t.references :load, null: false, foreign_key: true
      t.references :carrier, null: false, foreign_key: true
      t.references :match, null: false, foreign_key: true
      t.string :status, default: "pending_pickup", null: false
      t.date :scheduled_pickup_date, null: false
      t.date :scheduled_delivery_date, null: false
      t.date :actual_pickup_date
      t.date :actual_delivery_date
      t.boolean :delivered_on_time, default: true

      t.timestamps
    end

    add_index :shipments, :status
    add_index :shipments, :scheduled_pickup_date
    add_index :shipments, :scheduled_delivery_date
    add_index :shipments, :delivered_on_time
  end
end