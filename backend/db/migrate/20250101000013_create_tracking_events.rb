class CreateTrackingEvents < ActiveRecord::Migration[8.0]
  def change
    create_table :tracking_events do |t|
      t.references :shipment, null: false, foreign_key: true
      t.string :event_type, null: false
      t.string :status, null: false
      t.string :location
      t.decimal :latitude, precision: 10, scale: 6
      t.decimal :longitude, precision: 10, scale: 6
      t.text :description
      t.text :notes
      t.datetime :occurred_at, null: false
      t.string :reported_by
      t.string :source, default: 'manual'
      t.boolean :is_milestone, default: false
      t.decimal :temperature, precision: 5, scale: 2 # For temperature-controlled shipments
      t.decimal :humidity, precision: 5, scale: 2 # For humidity monitoring
      t.references :vehicle, foreign_key: true, null: true
      t.references :driver, foreign_key: true, null: true
      t.string :external_id # For third-party tracking integration
      t.text :metadata # JSON for additional data

      t.timestamps
    end

    add_index :tracking_events, :shipment_id
    add_index :tracking_events, :event_type
    add_index :tracking_events, :status
    add_index :tracking_events, :occurred_at
    add_index :tracking_events, :is_milestone
    add_index :tracking_events, :source
    add_index :tracking_events, [:latitude, :longitude]
    add_index :tracking_events, [:shipment_id, :occurred_at]
  end
end