require "test_helper"

class GameHintTest < ActiveSupport::TestCase
  setup do
    @player = players(:newbie)
    @game = @player.games.create!(
      cryptic: cryptics(:camisa), status: "in_progress", started_at: 1.minute.ago
    )
    @parameters = { player: @player, game_id: @game.id }
  end

  test "delivers exactly the requested hint data and records consumption" do
    expected = [
      { level: 1, puzzle_type: "contenedor" },
      { level: 2, definitions: [ "una prenda" ] },
      { level: 3, indicators: [ "metido en" ], material: [ "Mi", "el hogar" ] },
      { level: 4, hint: @game.cryptic.hint }
    ]
    expected.each_with_index do |payload, index|
      assert_equal payload, Games::Hint.call(**@parameters, level: index + 1)
      assert_equal index + 1, @game.reload.hints_count
      assert_equal 0, @game.attempts_count
      assert_nil @game.points
    end
  end

  test "rejects skipped and invalid levels without consuming hints" do
    [ 2, 4, 5, 0, nil, "1" ].each do |level|
      assert_raises(Game::ActionError) { Games::Hint.call(**@parameters, level: level) }
      assert_equal 0, @game.reload.hints_count
    end
  end

  test "repeated requests do not consume an additional hint or reset progress" do
    first = Games::Hint.call(**@parameters, level: 1)
    assert_equal first, Games::Hint.call(**@parameters, level: 1)
    assert_equal 1, @game.reload.hints_count
    Games::Hint.call(**@parameters, level: 2)
    assert_equal first, Games::Hint.call(**@parameters, level: 1)
    assert_equal 2, @game.reload.hints_count
  end

  test "reports missing fourth hint without counting it" do
    @game.update!(hints_count: 3)
    @game.cryptic.update!(hint: nil)

    error = assert_raises(Game::ActionError) { Games::Hint.call(**@parameters, level: 4) }
    assert_equal :missing_hint, error.code
    assert_equal 3, @game.reload.hints_count
  end

  test "rejects inaccessible unstarted and finished games" do
    assert_raises(ActiveRecord::RecordNotFound) do
      Games::Hint.call(**@parameters, player: players(:pedrito), level: 1)
    end
    @player.update!(blocked_at: Time.current)
    assert_raises(Game::ActionError) { Games::Hint.call(**@parameters, level: 1) }
    @player.update!(blocked_at: nil)
    @game.update!(status: "pending", started_at: nil)
    assert_raises(Game::ActionError) { Games::Hint.call(**@parameters, level: 1) }
    @game.update!(
      status: "surrendered", started_at: 1.minute.ago, finished_at: Time.current, points: 0
    )
    assert_raises(Game::ActionError) { Games::Hint.call(**@parameters, level: 1) }
  end

  test "consumed hints affect the eventual winning score" do
    Games::Hint.call(**@parameters, level: 1)
    game = Games::Attempt.call(
      **@parameters, answer: "CAMISA", type_points: 100, difficulty_multiplier: 2
    )

    assert_equal 168, game.points
    assert_equal 1, game.hints_count
  end
end
