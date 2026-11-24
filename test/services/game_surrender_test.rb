require "test_helper"

class GameSurrenderTest < ActiveSupport::TestCase
  setup do
    @player = players(:pedrito)
    @game = @player.games.create!(
      cryptic: cryptics(:camisa), status: "in_progress",
      started_at: 1.minute.ago, attempts_count: 2, hints_count: 1
    )
    @parameters = { player: @player, game_id: @game.id }
  end

  test "surrenders with zero points without consuming attempts or changing streak" do
    travel_to Time.current.change(usec: 0) do
      game = Games::Surrender.call(**@parameters)

      assert_equal "surrendered", game.status
      assert_equal 0, game.points
      assert_equal Time.current, game.finished_at
      assert_equal 2, game.attempts_count
      assert_equal 1, game.hints_count
      assert_equal 3, @player.reload.current_streak
      assert_equal 5, @player.best_streak
      assert_equal Date.current.yesterday, @player.last_streak_on
    end
  end

  test "repeated surrender preserves final time and does not overwrite a win" do
    surrendered = Games::Surrender.call(**@parameters)
    repeated = Games::Surrender.call(**@parameters)
    assert_equal surrendered.finished_at, repeated.finished_at
    assert_equal 0, repeated.points

    @game.reload.update!(status: "won", points: 144)
    result = Games::Surrender.call(**@parameters)
    assert_equal "won", result.status
    assert_equal 144, result.points
  end

  test "rejects other players blocked players and unstarted games" do
    assert_raises(ActiveRecord::RecordNotFound) do
      Games::Surrender.call(**@parameters, player: players(:newbie))
    end
    @player.update!(blocked_at: Time.current)
    assert_raises(Game::ActionError) { Games::Surrender.call(**@parameters) }
    @player.update!(blocked_at: nil)
    @game.update!(status: "pending", started_at: nil, attempts_count: 0, hints_count: 0)
    error = assert_raises(Game::ActionError) { Games::Surrender.call(**@parameters) }
    assert_equal :not_started, error.code
    assert_nil @game.reload.points
  end

  test "daily games use the same surrender service with zero points" do
    challenge = DailyChallenge.create!(date: Date.current, cryptic: @game.cryptic)
    @game.update!(daily_challenge: challenge)

    result = Games::Surrender.call(**@parameters)
    assert_equal "surrendered", result.status
    assert_equal 0, result.points
    assert_equal 3, @player.reload.current_streak
  end
end
