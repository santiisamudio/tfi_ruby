class StreaksController < ApplicationController
  allow_unauthenticated_access
  before_action :require_player

  def show
    @player = current_player
  end
end
