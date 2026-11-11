class PlayersController < ApplicationController
  allow_unauthenticated_access
  before_action :redirect_if_identified, only: %i[ new create ]
  before_action :redirect_unless_identified, only: :edit
  before_action :require_player, only: :update
  before_action :set_player, only: %i[ edit update ]

  def new
    @player = Player.new
  end

  def create
    @player = Player.new(player_params)

    if @player.save
      start_playing_as @player
      redirect_to after_choosing_name_url, notice: "Hola, #{@player.name}. Ya podés jugar."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @player.update(player_params)
      redirect_to edit_player_path, notice: "Nombre guardado: ahora sos #{@player.name}.", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    forget_current_player
    redirect_to new_player_path, notice: "Empezaste como otro jugador. Elegí su nombre.", status: :see_other
  end

  private
    def redirect_if_identified
      redirect_to edit_player_path if current_player
    end

    def redirect_unless_identified
      redirect_to new_player_path unless current_player
    end

    def set_player
      @player = Player.find(current_player.id)
    end

    def player_params
      params.expect(player: [ :name ])
    end
end
