require "test_helper"

class GamesControllerTest < ActionDispatch::IntegrationTest
  setup do
    post player_url, params: { player: { name: "Probador" } }
    @player = Player.find_by!(name: "Probador")
  end

  test "assigns starts and returns only authorized game data" do
    post games_url, params: { difficulty: "medio", player_id: players(:blocked).id }
    assert_response :success
    pending = response.parsed_body
    game = Game.find(pending.fetch("id"))
    assert_equal @player, game.player
    assert_equal "pending", pending["status"]
    %w[clue enumeration answer explanation hints puzzle_type].each { |key| assert_not pending.key?(key) }
    assert_equal "no-store", response.headers["Cache-Control"]

    post start_game_url(game)
    assert_response :success
    started = response.parsed_body
    assert_equal "in_progress", started["status"]
    assert_equal game.cryptic.clue, started["clue"]
    assert_equal({}, started["hints"])
    assert_not started.key?("answer")
    assert_not started.key?("explanation")

    post hint_game_url(game), params: { level: 1 }
    assert_response :success
    assert_equal({ "level" => 1, "puzzle_type" => "contenedor" }, response.parsed_body)

    get game_url(game)
    assert_response :success
    assert_equal({ "puzzle_type" => "contenedor" }, response.parsed_body["hints"])
    assert_not response.parsed_body.key?("answer")
  end

  test "surrender reveals solution and repeated requests preserve result" do
    game = @player.games.create!(cryptic: cryptics(:camisa), status: "in_progress", started_at: Time.current)
    post surrender_game_url(game)
    assert_response :success
    assert_equal "surrendered", response.parsed_body["status"]
    assert_equal "CAMISA", response.parsed_body["answer"]
    assert_equal game.cryptic.explanation, response.parsed_body["explanation"]
    assert_equal 0, response.parsed_body["points"]
    finished_at = game.reload.finished_at

    post surrender_game_url(game)
    assert_response :success
    assert_equal finished_at, game.reload.finished_at
  end

  test "does not allow access to another player's games" do
    other = players(:newbie).games.create!(cryptic: cryptics(:camisa))
    get game_url(other)
    assert_response :not_found
    assert_equal "game_not_found", response.parsed_body.dig("error", "code")
    post start_game_url(other)
    assert_response :not_found
    assert_nil other.reload.started_at
  end

  test "requires signed player identity and rejects blocked players" do
    delete player_url
    post games_url, params: { difficulty: "medio", player_id: @player.id }
    assert_response :unauthorized

    post player_url, params: { player: { name: "Bloqueable" } }
    Player.find_by!(name: "Bloqueable").update!(blocked_at: Time.current)
    post games_url, params: { difficulty: "medio" }
    assert_response :forbidden
    assert_equal "blocked_player", response.parsed_body.dig("error", "code")
  end

  test "reports invalid requests as json without creating games" do
    assert_no_difference "Game.count" do
      post games_url, params: {}
      assert_response :bad_request
      post games_url, params: { difficulty: "otra" }
      assert_response :unprocessable_content
    end
    game = @player.games.create!(cryptic: cryptics(:camisa), status: "in_progress", started_at: Time.current)
    post hint_game_url(game), params: { level: "1x" }
    assert_response :unprocessable_content
    assert_equal 0, game.reload.hints_count
  end

  test "returns a shared daily assignment and expires it when queried after midnight" do
    DailyChallenge.create!(date: Date.current, cryptic: cryptics(:camisa))
    post daily_games_url
    assert_response :success
    game = Game.find(response.parsed_body.fetch("id"))
    assert_equal Date.current.iso8601, response.parsed_body["daily_on"]

    travel_to Date.current.next_day.in_time_zone do
      get game_url(game)
      assert_response :success
      assert_equal "expired", response.parsed_body["status"]
      assert_equal 0, response.parsed_body["points"]
      assert_not response.parsed_body.key?("answer")
      post start_game_url(game)
      assert_response :unprocessable_content
    end
  end

  test "does not disable csrf protection for json endpoints" do
    previous = GamesController.allow_forgery_protection
    GamesController.allow_forgery_protection = true
    assert_no_difference "Game.count" do
      post games_url, params: { difficulty: "medio" }, as: :json
      assert_response :unprocessable_content
      assert_equal "invalid_csrf", response.parsed_body.dig("error", "code")
    end
  ensure
    GamesController.allow_forgery_protection = previous
  end
end
