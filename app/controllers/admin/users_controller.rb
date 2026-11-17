module Admin
  class UsersController < BaseController
    before_action :require_admin
    before_action :set_user, only: %i[edit update activate deactivate]

    def index
      @users = User.order(:email_address)
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)

      if @user.save
        redirect_to admin_users_path, notice: "Usuario creado correctamente."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      attributes = user_params
    
      if attributes[:password].blank?
        attributes.delete(:password)
        attributes.delete(:password_confirmation)
      end
    
      if @user.update(attributes)
        redirect_to admin_users_path, notice: "Usuario actualizado correctamente."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def activate
      @user.update!(active: true)
      redirect_to admin_users_path, notice: "Usuario activado."
    end

    def deactivate
      @user.update!(active: false)
      @user.sessions.destroy_all
      redirect_to admin_users_path, notice: "Usuario desactivado."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(
        :email_address,
        :password,
        :password_confirmation,
        :role
      )
    end
  end
end
