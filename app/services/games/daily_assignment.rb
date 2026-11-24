class Games::DailyAssignment
  def self.call(player:)
    Games::DailyExpiration.call(player: player)

    player.with_lock do
      raise Game::ActionError.new(:blocked_player) if player.blocked?

      challenge = Games::DailySelection.call
      existing = player.games.find_by(daily_challenge_id: challenge.id)
      next existing if existing

      if player.games.where(cryptic_id: challenge.cryptic_id).where.not(started_at: nil).exists?
        raise Game::ActionError.new(:already_played)
      end
      if player.games.open.exists?
        raise Game::ActionError.new(:open_game_exists)
      end
      unless challenge.cryptic.active?
        raise Game::ActionError.new(:inactive_cryptic)
      end

      player.games.create!(cryptic: challenge.cryptic, daily_challenge: challenge)
    end
  end
end
