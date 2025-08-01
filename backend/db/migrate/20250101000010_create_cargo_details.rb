class CreateCargoDetails < ActiveRecord::Migration[8.0]
  def change
    create_table :cargo_details do |t|
      t.references :load, null: false, foreign_key: true
      t.string :item_name, null: false
      t.text :item_description
      t.integer :quantity, null: false
      t.string :unit_type, null: false
      t.decimal :weight_per_unit, precision: 8, scale: 2
      t.decimal :total_weight, precision: 8, scale: 2
      t.string :dimensions
      t.decimal :volume, precision: 10, scale: 3
      t.decimal :value, precision: 10, scale: 2
      t.string :commodity_class
      t.string :hazmat_class
      t.string :nmfc_code
      t.string :packaging_type
      t.text :special_handling

      t.timestamps
    end

    add_index :cargo_details, :load_id
    add_index :cargo_details, :unit_type
    add_index :cargo_details, :commodity_class
    add_index :cargo_details, :hazmat_class
  end
end