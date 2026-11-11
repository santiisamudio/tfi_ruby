class StreakUpdater
  def initialize(player, today = Date.current)
    @player = player
    @today = today
  end

  def call
    return @player.current_streak if @player.streak_counted_today?(@today)

    if @player.streak_alive?(@today)
      @player.current_streak += 1
    else
      @player.current_streak = 1
    end

    if @player.current_streak > @player.best_streak
      @player.best_streak = @player.current_streak
    end

    @player.last_streak_on = @today
    @player.save!
    @player.current_streak
  end
end
