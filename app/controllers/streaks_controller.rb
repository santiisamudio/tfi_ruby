class StreaksController < ApplicationController
  allow_unauthenticated_access
  before_action :require_player

  def show
    @player = current_player
    @streak_help = ChatbotNode.find("streak")
  end
end
