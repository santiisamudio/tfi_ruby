require "test_helper"
require "minitest/mock"

class Admin::CatalogSyncsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @admin = users(:one)
    @admin.update!(role: "admin")
    @sync = CatalogSync.create!(
      source_url: Catalog::Download::DEFAULT_SOURCE_URL,
      user: @admin, version: "v1", status: "success"
    )
  end

  test "requires authentication for every action" do
    download = ->(**) { flunk "Unauthenticated request must not download" }
    Catalog::Download.stub(:call, download) do
      get admin_catalog_syncs_path
      assert_redirected_to new_session_path
      get admin_catalog_sync_path(@sync)
      assert_redirected_to new_session_path
      assert_no_difference "CatalogSync.count" do
        post admin_catalog_syncs_path
        assert_redirected_to new_session_path
      end
    end
  end

  test "denies editors every action and hides dashboard link" do
    sign_in_as(users(:two))
    get admin_root_path
    assert_response :success
    assert_select "a[href=?]", admin_catalog_syncs_path, count: 0

    download = ->(**) { flunk "Editor must not download" }
    Catalog::Download.stub(:call, download) do
      get admin_catalog_syncs_path
      assert_redirected_to root_path
      get admin_catalog_sync_path(@sync)
      assert_redirected_to root_path
      assert_no_difference "CatalogSync.count" do
        post admin_catalog_syncs_path
        assert_redirected_to root_path
      end
    end
  end

  test "shows the button and bounded history to administrators" do
    sign_in_as(@admin)
    get admin_root_path
    assert_select "a[href=?]", admin_catalog_syncs_path

    21.times do
      CatalogSync.create!(source_url: @sync.source_url, version: "v1", status: "unchanged")
    end
    get admin_catalog_syncs_path
    assert_response :success
    assert_not_includes response.body, Catalog::Download::DEFAULT_SOURCE_URL
    assert_select "form[action=?][method=post]", admin_catalog_syncs_path
    assert_select "tbody tr", count: 20
    assert_select "a[href=?]", admin_catalog_sync_path(@sync), count: 0
  end

  test "renders rejection messages as escaped text and supports seed records" do
    @sync.update!(
      user: nil, rejected_count: 1,
      error_details: [ { "source_id" => "cr-021", "messages" => [ "<script>alert(1)</script>" ] } ]
    )
    sign_in_as(@admin)
    get admin_catalog_sync_path(@sync)

    assert_response :success
    assert_not_includes response.body, @sync.source_url
    assert_select "dd", text: "Seeds"
    assert_select "h3", text: "cr-021"
    assert_select "li", text: "<script>alert(1)</script>"
    assert_select "li script", count: 0
  end

  test "runs synchronization with current admin and server URL not supplied parameters" do
    sign_in_as(@admin)
    catalog = {
      "version" => "v2", "generado" => "2026-11-26", "fuente" => "Prueba",
      "cripticos" => [ { "id" => "cr-rejected" } ]
    }
    download = ->(source_url:) {
      assert_equal Catalog::Download::DEFAULT_SOURCE_URL, source_url
      catalog
    }
    Catalog::Download.stub(:call, download) do
      assert_difference "CatalogSync.count", 1 do
        post admin_catalog_syncs_path, params: { user_id: users(:two).id, source_url: "http://untrusted.test" }
      end
    end

    sync = CatalogSync.order(:id).last
    assert_redirected_to admin_catalog_sync_path(sync)
    assert_response :see_other
    assert_equal @admin, sync.user
    assert_equal "success", sync.status
    assert_equal 1, sync.rejected_count
    follow_redirect!
    assert_response :success
    assert_select "h3", text: "cr-rejected"
    assert_equal I18n.t("catalog.sync_results.success"), flash[:notice]
  end

  test "displays unchanged and failed outcomes" do
    sign_in_as(@admin)
    catalog = {
      "version" => "v1", "generado" => "2026-11-26", "fuente" => "Prueba",
      "cripticos" => [ { "id" => "cr-001" } ]
    }
    Catalog::Download.stub(:call, catalog) { post admin_catalog_syncs_path }
    sync = CatalogSync.order(:id).last
    assert_equal "unchanged", sync.status
    assert_redirected_to admin_catalog_sync_path(sync)
    assert_equal I18n.t("catalog.sync_results.unchanged"), flash[:notice]

    failure = ->(**) { raise Catalog::Download::Error.new(:timeout) }
    Catalog::Download.stub(:call, failure) { post admin_catalog_syncs_path }
    sync = CatalogSync.order(:id).last
    assert_equal "failed", sync.status
    assert_redirected_to admin_catalog_sync_path(sync)
    assert_equal I18n.t("catalog.sync_results.failed"), flash[:alert]
    follow_redirect!
    assert_select "li", text: I18n.t("catalog.errors.timeout")
  end

  test "rejects POST without CSRF when forgery protection is enabled" do
    sign_in_as(@admin)
    previous = ActionController::Base.allow_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    download = ->(**) { flunk "Invalid CSRF must not download" }

    Catalog::Download.stub(:call, download) do
      assert_no_difference "CatalogSync.count" do
        post admin_catalog_syncs_path
        assert_response :unprocessable_content
      end
    end
  ensure
    ActionController::Base.allow_forgery_protection = previous
  end
end
