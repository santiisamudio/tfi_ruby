class Games::DailyExpiration
  def self.ensure_current!(game)
    if game.daily_challenge && game.daily_challenge.date != Date.current
      raise Game::ActionError.new(:daily_expired)
    end
  end

  def self.call(player:)
    player.with_lock do
      expired_games = player.games.open.joins(:daily_challenge)
        .where("daily_challenges.date < ?", Date.current).includes(:daily_challenge)

      expired_games.map do |game|
        deadline = game.daily_challenge.date.next_day.in_time_zone
        game.update!(status: "expired", finished_at: deadline, points: 0)
        game
      end
    end
  end
end
