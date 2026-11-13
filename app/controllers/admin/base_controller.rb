module Admin
    class BaseController < ApplicationController
      before_action :require_admin_or_editor
    end
  end
  