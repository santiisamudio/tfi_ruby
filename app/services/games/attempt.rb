class Games::Attempt
  def self.call(player:, game_id:, answer:, type_points:, difficulty_multiplier:)
    Games::DailyExpiration.call(player: player)

    player.with_lock do
      raise Game::ActionError.new(:blocked_player) if player.blocked?

      game = player.games.find(game_id)
      Games::DailyExpiration.ensure_current!(game)
      raise Game::ActionError.new(:not_started) if game.status == "pending"
      next game unless game.status == "in_progress"

      unless answer.is_a?(String)
        raise Game::ActionError.new(:invalid_answer)
      end
      normalized_answer = AnswerNormalizer.call(answer)
      raise Game::ActionError.new(:empty_answer) if normalized_answer.empty?

      game.attempts_count += 1
      if normalized_answer == AnswerNormalizer.call(game.cryptic.answer)
        finished_at = Time.current
        streak = StreakUpdater.call(player: player, today: finished_at.to_date)
        points = ScoreCalculator.call(
          type_points: type_points,
          difficulty_multiplier: difficulty_multiplier,
          difficulty: game.cryptic.difficulty,
          duration_seconds: finished_at - game.started_at,
          hints_count: game.hints_count,
          streak_days: streak
        )
        points *= 2 if game.daily_challenge_id
        game.assign_attributes(status: "won", finished_at: finished_at, points: points)
      elsif game.attempts_count == 5
        game.assign_attributes(status: "lost", finished_at: Time.current, points: 0)
      end

      game.save!
      game
    end
  end
end
