class GamesController < ApplicationController
  allow_unauthenticated_access
  before_action :require_json_player
  before_action :disable_response_caching

  rescue_from Game::ActionError, with: :render_action_error
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActionController::ParameterMissing, with: :render_missing_parameter
  rescue_from ActionController::InvalidAuthenticityToken, with: :render_invalid_csrf

  def create
    game = Games::Assignment.call(player: current_player, difficulty: params.expect(:difficulty))
    render json: Games::PublicState.call(game)
  end

  def daily
    game = Games::DailyAssignment.call(player: current_player)
    render json: Games::PublicState.call(game)
  end

  def show
    Games::DailyExpiration.call(player: current_player)
    game = current_player.games.find(params[:id])
    render json: Games::PublicState.call(game)
  end

  def start
    game = Games::Start.call(player: current_player, game_id: params[:id])
    render json: Games::PublicState.call(game)
  end

  def hint
    level = params.expect(:level)
    level = level.to_i if level.is_a?(String) && level.match?(/\A[1-4]\z/)
    payload = Games::Hint.call(player: current_player, game_id: params[:id], level: level)
    render json: payload
  end

  def surrender
    game = Games::Surrender.call(player: current_player, game_id: params[:id])
    render json: Games::PublicState.call(game)
  end

  private
    def require_json_player
      if current_player.nil?
        render_error(:player_required, :unauthorized)
      elsif current_player.blocked?
        render_error(:blocked_player, :forbidden)
      end
    end

    def disable_response_caching
      response.headers["Cache-Control"] = "no-store"
    end

    def render_action_error(error)
      render json: { error: { code: error.code, message: error.message } }, status: :unprocessable_content
    end

    def render_not_found
      render_error(:game_not_found, :not_found)
    end

    def render_missing_parameter
      render_error(:invalid_parameters, :bad_request)
    end

    def render_invalid_csrf
      render_error(:invalid_csrf, :unprocessable_content)
    end

    def render_error(code, status)
      render json: { error: { code: code, message: I18n.t("games.errors.#{code}", raise: true) } }, status: status
    end
end
