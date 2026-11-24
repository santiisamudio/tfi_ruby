require "test_helper"

class GamesShareResultTest < ActiveSupport::TestCase
  setup do
    @game = Game.new(player: players(:newbie), cryptic: cryptics(:camisa))
  end

  test "creates an encoded whatsapp link with results but no puzzle content" do
    @game.assign_attributes(
      status: "won", started_at: Time.current - 120, finished_at: Time.current,
      attempts_count: 2, hints_count: 3, points: 144
    )
    result = Games::ShareResult.call(@game)
    text = result.fetch(:text)

    assert_includes text, "Resuelto"
    assert_includes text, "Puntos: 144"
    assert_includes text, "Intentos: 2/5"
    assert_includes text, "Pistas utilizadas: 3/4"
    assert_includes text, "Tiempo: 120 segundos"
    [ @game.cryptic.answer, @game.cryptic.clue, @game.cryptic.hint, @game.cryptic.explanation,
      *@game.cryptic.definitions, *@game.cryptic.indicators, *@game.cryptic.material ].each do |secret|
      assert_not_includes text, secret
    end
    url = URI.parse(result.fetch(:whatsapp_url))
    assert_equal "https", url.scheme
    assert_equal "wa.me", url.host
    assert_equal [ [ "text", text ] ], URI.decode_www_form(url.query)
  end

  test "rejects pending and in progress games" do
    assert_raises(Game::ActionError) { Games::ShareResult.call(@game) }
    @game.assign_attributes(status: "in_progress", started_at: Time.current)
    assert_raises(Game::ActionError) { Games::ShareResult.call(@game) }
  end

  test "shares zero point outcomes and identifies the daily challenge date" do
    challenge = DailyChallenge.create!(date: Date.current.yesterday, cryptic: @game.cryptic)
    @game.daily_challenge = challenge
    { "lost" => "Intentos agotados", "surrendered" => "Me rendí", "expired" => "Desafío vencido" }.each do |status, label|
      @game.assign_attributes(status: status, finished_at: Time.current, points: 0)
      text = Games::ShareResult.call(@game).fetch(:text)

      assert_includes text, label
      assert_includes text, challenge.date.iso8601
      assert_includes text, "Puntos: 0"
      assert_not_includes text, "Tiempo:"
    end
  end
end
