module Admin
  class CatalogSyncsController < BaseController
    before_action :require_admin

    def index
      @catalog_syncs = CatalogSync.includes(:user).order(created_at: :desc, id: :desc).limit(20)
    end

    def show
      @catalog_sync = CatalogSync.find(params[:id])
    end

    def create
      sync = Catalog::Synchronize.call(user: Current.user)
      message = I18n.t("catalog.sync_results.#{sync.status}", raise: true)
      if sync.status == "failed"
        redirect_to admin_catalog_sync_path(sync), alert: message, status: :see_other
      else
        redirect_to admin_catalog_sync_path(sync), notice: message, status: :see_other
      end
    end
  end
end
