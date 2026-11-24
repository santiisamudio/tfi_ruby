require "test_helper"

class GamesDailyExpirationTest < ActiveSupport::TestCase
  test "expires pending and started daily games at local midnight without changing streaks" do
    challenge = DailyChallenge.create!(date: Date.current - 2, cryptic: cryptics(:camisa))
    deadline = challenge.date.next_day.in_time_zone
    pending = players(:newbie).games.create!(cryptic: challenge.cryptic, daily_challenge: challenge)
    started = players(:pedrito).games.create!(
      cryptic: challenge.cryptic, daily_challenge: challenge, status: "in_progress",
      started_at: deadline - 1.hour, attempts_count: 2, hints_count: 1
    )

    [ pending, started ].each do |game|
      result = Games::DailyExpiration.call(player: game.player)
      assert_equal [ game ], result
      game.reload
      assert_equal "expired", game.status
      assert_equal 0, game.points
      assert_equal deadline, game.finished_at
      assert_empty Games::DailyExpiration.call(player: game.player)
    end
    assert_nil pending.reload.started_at
    assert_equal 2, started.reload.attempts_count
    assert_equal 1, started.hints_count
    assert_equal 3, players(:pedrito).reload.current_streak
  end

  test "does not expire normal games current daily games or completed daily games" do
    normal = players(:newbie).games.create!(
      cryptic: cryptics(:camisa), status: "in_progress", started_at: 2.days.ago
    )
    current_challenge = DailyChallenge.create!(date: Date.current, cryptic: cryptics(:camisa))
    current = players(:pedrito).games.create!(
      cryptic: current_challenge.cryptic, daily_challenge: current_challenge
    )
    past_challenge = DailyChallenge.create!(date: Date.current.yesterday, cryptic: cryptics(:mate))
    finished_at = past_challenge.date.in_time_zone + 12.hours
    completed = players(:angela).games.create!(
      cryptic: past_challenge.cryptic, daily_challenge: past_challenge,
      status: "won", started_at: finished_at - 1.minute, finished_at: finished_at,
      attempts_count: 1, points: 210
    )

    [ normal, current, completed ].each do |game|
      assert_empty Games::DailyExpiration.call(player: game.player)
    end
    assert_equal "in_progress", normal.reload.status
    assert_equal "pending", current.reload.status
    assert_equal 210, completed.reload.points
  end

  test "daily games expire exactly at midnight in the configured timezone" do
    challenge = DailyChallenge.create!(date: Date.current, cryptic: cryptics(:camisa))
    game = players(:newbie).games.create!(cryptic: challenge.cryptic, daily_challenge: challenge)
    deadline = challenge.date.next_day.in_time_zone

    travel_to deadline - 1.second do
      assert_empty Games::DailyExpiration.call(player: game.player)
    end
    travel_to deadline do
      assert_equal [ game ], Games::DailyExpiration.call(player: game.player)
      assert_equal "expired", game.reload.status
    end
  end
end
