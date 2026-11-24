class AddDoubleDefinitionConstraintToCryptics < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :cryptics,
      "puzzle_type != 'doble_definicion' OR json_array_length(definitions) = 2",
      name: "cryptics_double_definition_count"
  end
end
