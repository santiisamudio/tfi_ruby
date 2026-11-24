class AddUniqueCrypticToDailyChallenges < ActiveRecord::Migration[8.1]
  def change
    remove_index :daily_challenges, :cryptic_id
    add_index :daily_challenges, :cryptic_id, unique: true
  end
end
