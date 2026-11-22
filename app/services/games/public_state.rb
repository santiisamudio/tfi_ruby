class Games::PublicState
  def self.call(game)
    state = {
      id: game.id,
      status: game.status,
      difficulty: game.cryptic.difficulty,
      daily_on: game.daily_challenge&.date,
      attempts_count: game.attempts_count,
      hints_count: game.hints_count,
      started_at: game.started_at,
      finished_at: game.finished_at,
      points: game.points
    }

    if game.started_at
      state[:clue] = game.cryptic.clue
      state[:enumeration] = game.cryptic.enumeration
      state[:elapsed_seconds] = ((game.finished_at || Time.current) - game.started_at).to_i
      hints = {}
      hints[:puzzle_type] = game.cryptic.puzzle_type if game.hints_count >= 1
      hints[:definitions] = game.cryptic.definitions if game.hints_count >= 2
      if game.hints_count >= 3
        hints[:indicators] = game.cryptic.indicators
        hints[:material] = game.cryptic.material
      end
      hints[:hint] = game.cryptic.hint if game.hints_count >= 4
      state[:hints] = hints
    end

    if %w[won lost surrendered].include?(game.status)
      state[:answer] = game.cryptic.answer
      state[:explanation] = game.cryptic.explanation
    end
    state
  end
end
