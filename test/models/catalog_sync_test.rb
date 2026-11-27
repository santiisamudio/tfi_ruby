require "test_helper"

class CatalogSyncTest < ActiveSupport::TestCase
  setup do
    @attributes = {
      source_url: "https://example.com/cryptics.json",
      version: "v1",
      status: "success"
    }
  end

  test "persists partial success with rejected cryptic details and an admin" do
    admin = users(:one)
    admin.update!(role: "admin")
    details = [ { "source_id" => "cr-021", "messages" => [ "Enumeracion incorrecta" ] } ]
    sync = CatalogSync.create!(
      **@attributes, user: admin, created_count: 8, updated_count: 2,
      rejected_count: 1, error_details: details
    )

    sync.reload
    assert_equal details, sync.error_details
    assert_equal 8, sync.created_count
    assert_equal 2, sync.updated_count
    assert_equal 1, sync.rejected_count
    assert_includes admin.catalog_syncs, sync
    assert_not admin.destroy
    assert CatalogSync.exists?(sync.id)
  end

  test "allows seeds without an executor and unchanged results" do
    sync = CatalogSync.create!(**@attributes, status: "unchanged")

    assert_nil sync.user
    assert_empty sync.reload.error_details
  end

  test "records download failure without a catalog version" do
    details = [ { "source_id" => nil, "messages" => [ "Tiempo de espera agotado" ] } ]
    sync = CatalogSync.create!(
      **@attributes, status: "failed", version: nil, error_details: details
    )

    assert_nil sync.reload.version
    assert_equal details, sync.error_details
  end

  test "rejects an editor as executor" do
    sync = CatalogSync.new(**@attributes, user: users(:two))

    assert_not sync.valid?
    assert sync.errors.of_kind?(:user, :admin_required)
  end

  test "requires a source and a recognized result and version for completed syncs" do
    sync = CatalogSync.new(**@attributes, source_url: "", status: "pending")
    assert_not sync.valid?
    assert sync.errors.of_kind?(:source_url, :blank)
    assert sync.errors.of_kind?(:status, :inclusion)

    %w[success unchanged].each do |status|
      sync = CatalogSync.new(**@attributes, status: status, version: nil)
      assert_not sync.valid?
      assert sync.errors.of_kind?(:version, :blank)
      assert_raises(ActiveRecord::StatementInvalid) { sync.save!(validate: false) }
    end
  end

  test "rejects negative and fractional counts" do
    %i[created_count updated_count deactivated_count rejected_count].each do |column|
      sync = CatalogSync.new(**@attributes, column => -1)
      assert_not sync.valid?
      assert sync.errors.of_kind?(column, :greater_than_or_equal_to)
      assert_raises(ActiveRecord::StatementInvalid) { sync.save!(validate: false) }

      sync[column] = 1.5
      assert_not sync.valid?
      assert sync.errors.of_kind?(column, :not_an_integer)
    end
  end

  test "rejects malformed error details" do
    [
      nil,
      {},
      [ "error" ],
      [ { "source_id" => "cr-021", "messages" => [] } ],
      [ { "source_id" => "", "messages" => [ "Error" ] } ],
      [ { "source_id" => nil, "messages" => [ nil ] } ],
      [ { "source_id" => nil, "messages" => [ "Error" ], "answer" => "SECRETO" } ]
    ].each do |details|
      sync = CatalogSync.new(**@attributes, error_details: details)
      assert_not sync.valid?
      assert sync.errors.of_kind?(:error_details, :invalid_sync_details)
    end

    sync = CatalogSync.new(**@attributes, error_details: {})
    assert_raises(ActiveRecord::StatementInvalid) { sync.save!(validate: false) }
  end
end
