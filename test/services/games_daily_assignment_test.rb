require "test_helper"

class GamesDailyAssignmentTest < ActiveSupport::TestCase
  test "creates and recovers one pending daily game per player" do
    challenge = DailyChallenge.create!(date: Date.current, cryptic: cryptics(:camisa))
    game = Games::DailyAssignment.call(player: players(:newbie))

    assert_equal challenge, game.daily_challenge
    assert_equal challenge.cryptic, game.cryptic
    assert_equal "pending", game.status
    assert_nil game.started_at
    assert_no_difference "Game.count" do
      assert_equal game, Games::DailyAssignment.call(player: players(:newbie))
    end
    other = Games::DailyAssignment.call(player: players(:pedrito))
    assert_equal challenge, other.daily_challenge
  end

  test "does not substitute another cryptic for a player who already played it" do
    challenge = DailyChallenge.create!(date: Date.current, cryptic: cryptics(:camisa))
    players(:newbie).games.create!(
      cryptic: challenge.cryptic, status: "surrendered",
      started_at: 1.minute.ago, finished_at: Time.current, points: 0
    )

    assert_no_difference "Game.count" do
      error = assert_raises(Game::ActionError) { Games::DailyAssignment.call(player: players(:newbie)) }
      assert_equal :already_played, error.code
    end
    assert_equal challenge, DailyChallenge.find_by!(date: Date.current)
  end

  test "rejects blocked players and does not replace an open normal game" do
    DailyChallenge.create!(date: Date.current, cryptic: cryptics(:camisa))
    normal = players(:newbie).games.create!(cryptic: cryptics(:mate))

    error = assert_raises(Game::ActionError) { Games::DailyAssignment.call(player: players(:newbie)) }
    assert_equal :open_game_exists, error.code
    assert_equal "pending", normal.reload.status
    error = assert_raises(Game::ActionError) { Games::DailyAssignment.call(player: players(:blocked)) }
    assert_equal :blocked_player, error.code
  end

  test "expires yesterday's game before assigning today's challenge" do
    yesterday = DailyChallenge.create!(date: Date.current.yesterday, cryptic: cryptics(:camisa))
    old_game = players(:newbie).games.create!(cryptic: yesterday.cryptic, daily_challenge: yesterday)

    game = Games::DailyAssignment.call(player: players(:newbie))
    assert_equal "expired", old_game.reload.status
    assert_equal 0, old_game.points
    assert_equal cryptics(:mate), game.cryptic
    assert_equal Date.current, game.daily_challenge.date
  end

  test "normal assignment can proceed after expiration of a daily game" do
    yesterday = DailyChallenge.create!(date: Date.current.yesterday, cryptic: cryptics(:camisa))
    old_game = players(:newbie).games.create!(cryptic: yesterday.cryptic, daily_challenge: yesterday)

    game = Games::Assignment.call(player: players(:newbie), difficulty: "facil")
    assert_equal "expired", old_game.reload.status
    assert_nil game.daily_challenge_id
    assert_equal cryptics(:mate), game.cryptic
  end

  test "keeps completed daily results when requested again" do
    challenge = DailyChallenge.create!(date: Date.current, cryptic: cryptics(:camisa))
    game = players(:newbie).games.create!(
      cryptic: challenge.cryptic, daily_challenge: challenge,
      status: "won", started_at: Time.current, finished_at: Time.current,
      attempts_count: 1, points: 420
    )

    assert_equal game, Games::DailyAssignment.call(player: players(:newbie))
    assert_equal 420, game.reload.points
  end
end
