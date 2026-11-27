class PointsRanking
  def self.call(week:, difficulty:)
    new(week, difficulty).call
  end

  def initialize(week, difficulty)
    @week = week
    @difficulty = difficulty
  end

  def call
    scores = solved_games.group_by { |game| game.player }.map do |player, games|
      PlayerScore.new(player, games)
    end
    scores.sort { |first, second| compare(first, second) }
  end

  private
    def solved_games
      games = Game.where(status: "won").joins(:player).merge(Player.not_blocked).includes(:player)
      if @week
        games = games.where(finished_at: Time.current.beginning_of_week..Time.current)
      end
      if @difficulty
        games = games.joins(:cryptic).merge(Cryptic.with_difficulty(@difficulty))
      end
      games
    end

    def compare(first, second)
      if first.points != second.points
        second.points <=> first.points
      elsif first.average_seconds != second.average_seconds
        first.average_seconds <=> second.average_seconds
      else
        first.player.normalized_name <=> second.player.normalized_name
      end
    end
end
