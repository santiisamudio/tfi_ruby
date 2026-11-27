class PlayerScore
  attr_reader :player, :games

  def initialize(player, games)
    @player = player
    @games = games
  end

  def points
    games.sum { |game| game.points }
  end

  def solved_count
    games.size
  end

  def average_seconds
    if games.any?
      total = games.sum { |game| game.finished_at - game.started_at }
      (total / games.size).round
    end
  end

  def without_hints_percentage
    if games.any?
      without_hints = games.count { |game| game.hints_count == 0 }
      (without_hints * 100.0 / games.size).round
    end
  end
end
