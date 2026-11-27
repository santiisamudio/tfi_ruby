module LeaderboardsHelper
  MEDALS = %w[ gold silver bronze ].freeze

  def medal_for(position)
    if position <= MEDALS.size
      MEDALS[position - 1]
    end
  end

  def duration_text(seconds)
    minutes = seconds / 60
    rest = seconds % 60
    if minutes > 0
      "#{minutes} min #{rest} s"
    else
      "#{rest} s"
    end
  end
end
