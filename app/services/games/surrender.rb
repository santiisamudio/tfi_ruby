class Games::Surrender
  def self.call(player:, game_id:)
    Games::DailyExpiration.call(player: player)

    player.with_lock do
      raise Game::ActionError.new(:blocked_player) if player.blocked?

      game = player.games.find(game_id)
      Games::DailyExpiration.ensure_current!(game)
      raise Game::ActionError.new(:not_started) if game.status == "pending"
      next game unless game.status == "in_progress"

      game.update!(status: "surrendered", finished_at: Time.current, points: 0)
      game
    end
  end
end
