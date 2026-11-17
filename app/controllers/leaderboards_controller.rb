class LeaderboardsController < ApplicationController
  TOP = 20

  allow_unauthenticated_access

  def show
    @players = Player.streak_ranking.limit(TOP)
    if current_player
      @current_player_position = current_player.streak_position
    end
  end
end
