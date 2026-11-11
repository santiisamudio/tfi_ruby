class CreatePlayers < ActiveRecord::Migration[8.1]
  def change
    create_table :players do |t|
      t.string :name, null: false
      t.string :normalized_name, null: false
      t.string :token, null: false
      t.datetime :blocked_at
      t.integer :current_streak, null: false, default: 0
      t.integer :best_streak, null: false, default: 0
      t.date :last_streak_on

      t.timestamps
    end
    add_index :players, :token, unique: true
    add_index :players, :normalized_name, unique: true

    add_check_constraint :players, "length(name) BETWEEN 3 AND 20", name: "players_name_length"
    add_check_constraint :players, "name = trim(name)", name: "players_name_trimmed"
    add_check_constraint :players, "current_streak >= 0", name: "players_current_streak_not_negative"
    add_check_constraint :players, "best_streak >= current_streak", name: "players_best_streak_at_least_current"
  end
end
