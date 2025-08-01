class CreateLoadRequirements < ActiveRecord::Migration[8.0]
  def change
    create_table :load_requirements do |t|
      t.references :load, null: false, foreign_key: true
      t.string :requirement_type, null: false
      t.text :requirement_value
      t.boolean :is_mandatory, default: true, null: false
      t.text :description

      t.timestamps
    end

    add_index :load_requirements, [:load_id, :requirement_type]
    add_index :load_requirements, :requirement_type
    add_index :load_requirements, :is_mandatory
  end
end