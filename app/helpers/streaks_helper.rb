module StreaksHelper
  STREAK_TILES_LIMIT = 14

  def days_count(days)
    pluralize(days, "día", plural: "días")
  end
end
