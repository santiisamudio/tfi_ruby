require "test_helper"

class GameAttemptTest < ActiveSupport::TestCase
  setup do
    @player = players(:newbie)
    @game = @player.games.create!(
      cryptic: cryptics(:camisa), status: "in_progress", started_at: 1.minute.ago
    )
    @parameters = { player: @player, game_id: @game.id, type_points: 100, difficulty_multiplier: 2 }
  end

  test "rejects empty and malformed answers without consuming attempts" do
    [ "", " ", "!!!", nil, [ "CAMISA" ] ].each do |answer|
      assert_raises(Game::ActionError) { Games::Attempt.call(**@parameters, answer: answer) }
      assert_equal 0, @game.reload.attempts_count
      assert_equal "in_progress", @game.status
    end
  end

  test "records wrong answers and loses exactly on the fifth attempt without increasing streak" do
    4.times do |index|
      game = Games::Attempt.call(**@parameters, answer: "otra")
      assert_equal index + 1, game.attempts_count
      assert_equal "in_progress", game.status
      assert_nil game.points
    end
    game = Games::Attempt.call(**@parameters, answer: "otra")
    assert_equal "lost", game.status
    assert_equal 5, game.attempts_count
    assert_equal 0, game.points
    assert_equal 0, @player.reload.current_streak
    assert_not_nil game.finished_at
  end

  test "normalizes correct answer and keeps repeated completion unchanged" do
    game = Games::Attempt.call(**@parameters, answer: " C\u00C1MISA! ")
    assert_equal "won", game.status
    assert_equal 210, game.points
    assert_equal 1, game.attempts_count
    assert_equal 1, @player.reload.current_streak
    finished_at = game.finished_at

    repeated = Games::Attempt.call(**@parameters, answer: "CAMISA")
    assert_equal finished_at, repeated.finished_at
    assert_equal 210, repeated.points
    assert_equal 1, repeated.attempts_count
    assert_equal 1, @player.reload.current_streak
  end

  test "allows a correct fifth attempt" do
    @game.update!(attempts_count: 4)

    game = Games::Attempt.call(**@parameters, answer: "CAMISA")
    assert_equal "won", game.status
    assert_equal 5, game.attempts_count
  end

  test "rolls back attempt and streak when scoring fails" do
    assert_raises(ArgumentError) do
      Games::Attempt.call(**@parameters, answer: "CAMISA", difficulty_multiplier: 0)
    end

    assert_equal "in_progress", @game.reload.status
    assert_equal 0, @game.attempts_count
    assert_nil @game.points
    assert_equal 0, @player.reload.current_streak
    assert_nil @player.last_streak_on
  end

  test "counts the resolution day rather than the start day and does not increment twice that day" do
    @game.update!(started_at: 2.days.ago)
    Games::Attempt.call(**@parameters, answer: "CAMISA")
    assert_equal Date.current, @player.reload.last_streak_on
    assert_equal 1, @player.current_streak

    second = @player.games.create!(
      cryptic: cryptics(:mate), status: "in_progress", started_at: Time.current
    )
    Games::Attempt.call(**@parameters, game_id: second.id, answer: "MATE", difficulty_multiplier: 1)
    assert_equal 1, @player.reload.current_streak
  end

  test "rejects other players blocked players and unstarted games" do
    assert_raises(ActiveRecord::RecordNotFound) do
      Games::Attempt.call(**@parameters, player: players(:pedrito), answer: "CAMISA")
    end
    @player.update!(blocked_at: Time.current)
    assert_raises(Game::ActionError) { Games::Attempt.call(**@parameters, answer: "CAMISA") }
    @player.update!(blocked_at: nil)
    @game.update!(status: "pending", started_at: nil)
    error = assert_raises(Game::ActionError) { Games::Attempt.call(**@parameters, answer: "CAMISA") }
    assert_equal :not_started, error.code
    assert_equal 0, @game.reload.attempts_count
  end
end
