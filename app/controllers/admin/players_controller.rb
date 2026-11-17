module Admin
  class PlayersController < BaseController
    before_action :require_admin
    before_action :set_player, only: %i[block unblock]

    def index
      @players = Player.order(score: :desc, name: :asc)
    end

    def block
      @player.update!(blocked_at: Time.current)
      redirect_to admin_players_path, notice: "Jugador bloqueado correctamente."
    end

    def unblock
      @player.update!(blocked_at: nil)
      redirect_to admin_players_path, notice: "Jugador desbloqueado correctamente."
    end

    private

    def set_player
      @player = Player.find(params[:id])
    end
  end
end
