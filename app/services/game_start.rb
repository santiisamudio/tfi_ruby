class GameStart
  def self.call(player:, game_id:)
    player.with_lock do
      raise Game::ActionError.new(:blocked_player) if player.blocked?

      game = player.games.find(game_id)
      unless Game::OPEN_STATUSES.include?(game.status)
        raise Game::ActionError.new(:finished_game)
      end
      if game.daily_challenge
        raise Game::ActionError.new(:daily_not_supported)
      end
      next game if game.status == "in_progress"

      unless game.cryptic.active?
        raise Game::ActionError.new(:inactive_cryptic)
      end
      if player.games.where(cryptic_id: game.cryptic_id).where.not(started_at: nil).exists?
        raise Game::ActionError.new(:already_played)
      end

      game.update!(status: "in_progress", started_at: Time.current)
      game
    end
  end
end
