require "test_helper"

class GameStartTest < ActiveSupport::TestCase
  setup do
    @player = players(:newbie)
    @game = @player.games.create!(cryptic: cryptics(:camisa))
  end

  test "starts with server time and repeated requests preserve that time" do
    travel_to Time.current.change(usec: 0) do
      started = GameStart.call(player: @player, game_id: @game.id)
      assert_equal "in_progress", started.status
      assert_equal Time.current, started.started_at
      assert_nil started.finished_at
      assert_nil started.points

      travel 1.hour
      again = GameStart.call(player: @player, game_id: @game.id)
      assert_equal started.started_at, again.started_at
    end
  end

  test "does not expose another player's game or start for a blocked player" do
    assert_raises(ActiveRecord::RecordNotFound) do
      GameStart.call(player: players(:pedrito), game_id: @game.id)
    end
    @player.update!(blocked_at: Time.current)
    error = assert_raises(Game::ActionError) do
      GameStart.call(player: @player, game_id: @game.id)
    end
    assert_equal :blocked_player, error.code
    assert_nil @game.reload.started_at
  end

  test "rejects inactive assignments and finished games" do
    @game.cryptic.update!(active: false)
    error = assert_raises(Game::ActionError) do
      GameStart.call(player: @player, game_id: @game.id)
    end
    assert_equal :inactive_cryptic, error.code

    @game.update!(
      status: "surrendered", started_at: 1.minute.ago, finished_at: Time.current, points: 0
    )
    error = assert_raises(Game::ActionError) do
      GameStart.call(player: @player, game_id: @game.id)
    end
    assert_equal :finished_game, error.code
  end
end
