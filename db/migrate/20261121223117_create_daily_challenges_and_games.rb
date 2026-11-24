class CreateDailyChallengesAndGames < ActiveRecord::Migration[8.1]
  def change
    create_table :daily_challenges do |t|
      t.date :date, null: false
      t.references :cryptic, null: false, foreign_key: true
      t.timestamps
    end

    add_index :daily_challenges, :date, unique: true
    # The composite foreign key keeps a daily game's cryptic consistent with its challenge.
    add_index :daily_challenges, [ :id, :cryptic_id ], unique: true

    create_table :games do |t|
      t.references :player, null: false, foreign_key: true
      t.references :cryptic, null: false, foreign_key: true
      t.references :daily_challenge
      t.string :status, null: false, default: "pending"
      t.integer :attempts_count, null: false, default: 0
      t.integer :hints_count, null: false, default: 0
      t.datetime :started_at
      t.datetime :finished_at
      t.integer :points
      t.timestamps
    end

    add_foreign_key :games, :daily_challenges,
      column: [ :daily_challenge_id, :cryptic_id ], primary_key: [ :id, :cryptic_id ]
    add_index :games, :player_id, unique: true,
      where: "status IN ('pending', 'in_progress')", name: "index_games_one_open_per_player"
    add_index :games, [ :player_id, :cryptic_id ], unique: true,
      where: "started_at IS NOT NULL", name: "index_games_one_started_per_cryptic"
    add_index :games, [ :player_id, :daily_challenge_id ], unique: true,
      where: "daily_challenge_id IS NOT NULL", name: "index_games_one_daily_per_player"

    add_check_constraint :games, "attempts_count BETWEEN 0 AND 5", name: "games_attempts_range"
    add_check_constraint :games, "hints_count BETWEEN 0 AND 4", name: "games_hints_range"
    add_check_constraint :games,
      "started_at IS NULL OR finished_at IS NULL OR finished_at >= started_at",
      name: "games_timestamp_order"
    add_check_constraint :games, <<~SQL.squish, name: "games_state_consistency"
      (status = 'pending' AND started_at IS NULL AND finished_at IS NULL
        AND points IS NULL AND attempts_count = 0 AND hints_count = 0)
      OR (status = 'in_progress' AND started_at IS NOT NULL AND finished_at IS NULL
        AND points IS NULL AND attempts_count < 5)
      OR (status = 'won' AND started_at IS NOT NULL AND finished_at IS NOT NULL
        AND points IS NOT NULL AND points >= 10 AND attempts_count >= 1)
      OR (status = 'lost' AND started_at IS NOT NULL AND finished_at IS NOT NULL
        AND points IS NOT NULL AND points = 0 AND attempts_count = 5)
      OR (status = 'surrendered' AND started_at IS NOT NULL AND finished_at IS NOT NULL
        AND points IS NOT NULL AND points = 0 AND attempts_count < 5)
      OR (status = 'expired' AND daily_challenge_id IS NOT NULL AND finished_at IS NOT NULL
        AND points IS NOT NULL AND points = 0
        AND (started_at IS NOT NULL OR (attempts_count = 0 AND hints_count = 0)))
    SQL
  end
end
