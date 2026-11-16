require "test_helper"

class StreakUpdaterTest < ActiveSupport::TestCase
  test "solving the day after continues the streak" do
    player = players(:pedrito)

    assert_equal 4, StreakUpdater.call(player: player)
    assert_equal 5, player.reload.best_streak
  end

  test "a missed day starts over and keeps the best streak" do
    player = players(:lucia)

    assert_equal 1, StreakUpdater.call(player: player)
    assert_equal 7, player.reload.best_streak
  end
end
