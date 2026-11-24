class CreateCryptics < ActiveRecord::Migration[8.1]
  def change
      create_table :cryptics do |t|
        t.string :source_id, null: false
        t.text :clue, null: false
        t.string :enumeration, null: false
        t.string :answer, null: false
        t.json :definitions, null: false
        t.json :indicators, null: false
        t.json :material, null: false
        t.string :puzzle_type, null: false
        t.string :difficulty, null: false
        t.text :hint
        t.text :explanation
        t.string :author
        t.boolean :active, null: false, default: true

        t.timestamps
      end

      add_index :cryptics, :source_id, unique: true

      %w[source_id clue enumeration answer].each do |column|
        add_check_constraint :cryptics, "length(trim(#{column})) > 0", name: "cryptics_#{column}_not_empty"
      end

      add_check_constraint :cryptics,
        "puzzle_type IN ('anagrama', 'oculta', 'charada', 'contenedor', 'inversion', 'supresion', 'homofono', 'doble_definicion', 'iniciales', 'finales', 'sustitucion', 'simbolos', 'combinada')",
        name: "cryptics_puzzle_type_allowed"
      add_check_constraint :cryptics, "difficulty IN ('facil', 'medio', 'avanzado')", name: "cryptics_difficulty_allowed"
      add_check_constraint :cryptics, "active IN (0, 1)", name: "cryptics_active_boolean"

      %w[definitions indicators material].each do |column|
        add_check_constraint :cryptics,
          "CASE WHEN json_valid(#{column}) THEN json_type(#{column}) = 'array' ELSE 0 END",
          name: "cryptics_#{column}_array"
    end
  end
end
