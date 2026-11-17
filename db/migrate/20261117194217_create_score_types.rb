class CreateScoreTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :score_types do |t|
      t.string :name, null: false
      t.integer :points, default: 0, null: false
      t.decimal :multiplier, precision: 8, scale: 2, default: 1.0, null: false

      t.timestamps
    end

    add_index :score_types, :name, unique: true
  end
end
