module PlayerIdentification
  extend ActiveSupport::Concern

  included do
    helper_method :current_player
  end

  private
    def current_player
      @current_player ||= find_player_by_cookie
    end

    def find_player_by_cookie
      token = cookies.signed[:player_token]
      Player.find_by(token: token) if token
    end

    def require_player
      if current_player.nil?
        session[:return_to_after_choosing_name] = request.url if request.get?
        redirect_to new_player_path, flash: { name_required: true }
      elsif current_player.blocked?
        redirect_to edit_player_path, alert: "Tu nombre está bloqueado: con este jugador no podés seguir jugando."
      end
    end

    def after_choosing_name_url
      session.delete(:return_to_after_choosing_name) || root_url
    end

    def start_playing_as(player)
      cookies.signed.permanent[:player_token] = { value: player.token, httponly: true, same_site: :lax }
      @current_player = player
    end

    def forget_current_player
      cookies.delete(:player_token)
      @current_player = nil
    end
end
