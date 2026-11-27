class LeaderboardsController < ApplicationController
  TOP = 20
  TABS = %w[ week all_time streaks ].freeze

  allow_unauthenticated_access

  def show
    @tab = "week"
    @tab = params[:tab] if TABS.include?(params[:tab])
    @difficulty = params[:difficulty] if Cryptic::DIFFICULTIES.include?(params[:difficulty])

    if @tab == "streaks"
      load_streak_ranking
    else
      load_points_ranking
    end
  end

  private
    def load_streak_ranking
      @page = Player.streak_ranking.page(params[:page]).per(TOP)
      @scores = @page.map { |player| player.all_time_score }
      if current_player && @page.first_page?
        position = current_player.streak_position
        if position && position > TOP
          @current_player_position = position
          @current_player_score = current_player.all_time_score
        end
      end
    end

    def load_points_ranking
      ranking = PointsRanking.call(week: @tab == "week", difficulty: @difficulty)
      @page = Kaminari.paginate_array(ranking).page(params[:page]).per(TOP)
      @scores = @page
      if current_player
        index = ranking.index { |score| score.player == current_player }
        if index && index >= TOP && @page.first_page?
          @current_player_position = index + 1
          @current_player_score = ranking[index]
        end
      end
    end
end
