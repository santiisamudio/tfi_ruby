require "test_helper"

class GamesDailyActionsTest < ActiveSupport::TestCase
  setup do
    @player = players(:newbie)
    @challenge = DailyChallenge.create!(date: Date.current, cryptic: cryptics(:camisa))
    @game = @player.games.create!(cryptic: @challenge.cryptic, daily_challenge: @challenge)
    @parameters = { player: @player, game_id: @game.id }
  end

  test "daily start and hints reuse the normal services and a win doubles the final score" do
    Games::Start.call(**@parameters)
    assert_equal "in_progress", @game.reload.status
    assert_equal({ level: 1, puzzle_type: "contenedor" }, Games::Hint.call(**@parameters, level: 1))

    won = Games::Attempt.call(**@parameters, answer: "CAMISA", type_points: 100, difficulty_multiplier: 2)
    assert_equal "won", won.status
    assert_equal 336, won.points
    assert_equal 1, @player.reload.current_streak

    repeated = Games::Attempt.call(**@parameters, answer: "CAMISA", type_points: 100, difficulty_multiplier: 2)
    assert_equal 336, repeated.points
    assert_equal 1, repeated.attempts_count
    assert_equal 1, @player.reload.current_streak
  end

  test "daily minimum is twice the normal minimum" do
    Games::Start.call(**@parameters)
    (1..4).each { |level| Games::Hint.call(**@parameters, level: level) }

    game = Games::Attempt.call(
      **@parameters, answer: "CAMISA", type_points: 10, difficulty_multiplier: 0.1
    )
    assert_equal 20, game.points
  end

  test "daily fifth wrong answer gives zero points and no streak" do
    Games::Start.call(**@parameters)
    5.times do
      Games::Attempt.call(**@parameters, answer: "otra", type_points: 100, difficulty_multiplier: 2)
    end

    assert_equal "lost", @game.reload.status
    assert_equal 0, @game.points
    assert_equal 0, @player.reload.current_streak
  end

  test "all actions reject a previous day's game and persist its expiration" do
    Games::Start.call(**@parameters)
    deadline = @challenge.date.next_day.in_time_zone

    travel_to deadline do
      actions = [
        -> { Games::Start.call(**@parameters) },
        -> { Games::Hint.call(**@parameters, level: 1) },
        -> { Games::Attempt.call(**@parameters, answer: "CAMISA", type_points: 100, difficulty_multiplier: 2) },
        -> { Games::Surrender.call(**@parameters) }
      ]
      actions.each do |action|
        error = assert_raises(Game::ActionError, &action)
        assert_equal :daily_expired, error.code
        assert_equal "expired", @game.reload.status
        assert_equal 0, @game.points
        assert_equal deadline, @game.finished_at
        assert_equal 0, @game.attempts_count
        assert_equal 0, @game.hints_count
      end
      assert_equal 0, @player.reload.current_streak
    end
  end

  test "does not start a daily assignment before its date" do
    travel_to @challenge.date.yesterday.in_time_zone + 12.hours do
      error = assert_raises(Game::ActionError) { Games::Start.call(**@parameters) }
      assert_equal :daily_expired, error.code
      assert_equal "pending", @game.reload.status
      assert_nil @game.started_at
    end
  end
end
