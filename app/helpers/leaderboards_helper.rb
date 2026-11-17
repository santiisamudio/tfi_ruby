module LeaderboardsHelper
  MEDALS = %w[ gold silver bronze ].freeze

  def medal_for(position)
    if position <= MEDALS.size
      MEDALS[position - 1]
    end
  end
end
