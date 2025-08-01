class CreateMatches < ActiveRecord::Migration[8.0]
  def change
    create_table :matches do |t|
      t.references :load, null: false, foreign_key: true
      t.references :carrier, null: false, foreign_key: true
      t.string :status, default: "pending", null: false
      t.decimal :match_score, precision: 5, scale: 2, default: 0.0
      t.decimal :rate_offered, precision: 10, scale: 2
      t.decimal :rate_accepted, precision: 10, scale: 2
      t.datetime :estimated_pickup_time
      t.datetime :estimated_delivery_time
      t.decimal :distance_to_pickup, precision: 8, scale: 2
      t.decimal :fuel_cost_estimate, precision: 8, scale: 2
      t.decimal :margin_estimate, precision: 8, scale: 2
      t.text :notes
      t.datetime :matched_at
      t.datetime :accepted_at
      t.datetime :rejected_at
      t.datetime :expired_at
      t.string :rejection_reason

      t.timestamps
    end

    add_index :matches, [:load_id, :carrier_id], unique: true
    add_index :matches, :status
    add_index :matches, :match_score
    add_index :matches, :matched_at
    add_index :matches, :accepted_at
  end
end