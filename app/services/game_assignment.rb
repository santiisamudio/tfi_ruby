class GameAssignment
  def self.call(player:, difficulty:)
    player.with_lock do
      raise Game::ActionError.new(:blocked_player) if player.blocked?
      unless Cryptic::DIFFICULTIES.include?(difficulty)
        raise Game::ActionError.new(:invalid_difficulty)
      end

      existing = player.games.open.first
      if existing
        if existing.daily_challenge && existing.daily_challenge.date != Date.current
          raise Game::ActionError.new(:daily_expired)
        end
        next existing
      end

      played_ids = player.games.where.not(started_at: nil).select(:cryptic_id)
      cryptic = Cryptic.active.with_difficulty(difficulty)
        .where.not(id: played_ids).order(Arel.sql("RANDOM()")).first
      raise Game::ActionError.new(:no_cryptics) unless cryptic

      player.games.create!(cryptic: cryptic)
    end
  end
end
