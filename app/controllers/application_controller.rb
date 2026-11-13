class ApplicationController < ActionController::Base
  include Authentication
  include PlayerIdentification
  allow_browser versions: :modern
  stale_when_importmap_changes

  private

  def require_admin
    redirect_to root_path, alert: "No tenés permisos para acceder." unless Current.user&.admin?
  end

  def require_admin_or_editor
    redirect_to root_path, alert: "No tenés permisos para acceder." unless Current.user&.role.in?(User::ROLES)
  end
end


