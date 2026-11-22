require "test_helper"

class GameAssignmentTest < ActiveSupport::TestCase
  test "assigns an eligible cryptic without starting the clock" do
    game = GameAssignment.call(player: players(:newbie), difficulty: "medio")

    assert_equal cryptics(:camisa), game.cryptic
    assert_equal "pending", game.status
    assert_nil game.started_at
    assert_nil game.points
  end

  test "recovers an open game without resetting progress or changing difficulty" do
    game = players(:newbie).games.create!(
      cryptic: cryptics(:camisa), status: "in_progress",
      started_at: 1.hour.ago, attempts_count: 2, hints_count: 1
    )
    original_start = game.started_at

    assert_no_difference "Game.count" do
      recovered = GameAssignment.call(player: players(:newbie), difficulty: "facil")
      assert_equal game, recovered
      assert_equal original_start, recovered.started_at
      assert_equal 2, recovered.attempts_count
      assert_equal 1, recovered.hints_count
    end
  end

  test "reports exhausted or inactive catalog instead of repeating a cryptic" do
    players(:newbie).games.create!(
      cryptic: cryptics(:camisa), status: "surrendered",
      started_at: 1.minute.ago, finished_at: Time.current, points: 0
    )
    error = assert_raises(Game::ActionError) do
      GameAssignment.call(player: players(:newbie), difficulty: "medio")
    end
    assert_equal :no_cryptics, error.code

    cryptics(:mate).update!(active: false)
    assert_raises(Game::ActionError) do
      GameAssignment.call(player: players(:newbie), difficulty: "facil")
    end
  end

  test "rejects blocked players and invalid difficulty without creating games" do
    assert_no_difference "Game.count" do
      error = assert_raises(Game::ActionError) do
        GameAssignment.call(player: players(:blocked), difficulty: "medio")
      end
      assert_equal :blocked_player, error.code

      error = assert_raises(Game::ActionError) do
        GameAssignment.call(player: players(:newbie), difficulty: "otra")
      end
      assert_equal :invalid_difficulty, error.code
    end
  end
end
