require "test_helper"
require "minitest/mock"

class CatalogSynchronizeTest < ActiveSupport::TestCase
  setup do
    @source_url = "https://example.com/cryptics.json"
    @mate = entry_for(cryptics(:mate))
    @camisa = entry_for(cryptics(:camisa))
    @catalog = {
      "version" => "v1", "generado" => "2026-11-26",
      "fuente" => "Prueba", "cripticos" => [ @mate, @camisa ]
    }
  end

  test "creates and updates by source ID and associates the admin" do
    admin = users(:one)
    admin.update!(role: "admin")
    @catalog["cripticos"] = [ @mate.merge("autor" => "Autor actualizado"), @camisa, @mate.merge("id" => "cr-new") ]

    result = nil
    assert_difference [ "Cryptic.count", "CatalogSync.count" ], 1 do
      result = synchronize(user: admin)
    end
    assert_equal "success", result.reload.status
    assert_equal admin, result.user
    assert_equal @source_url, result.source_url
    assert_equal "v1", result.version
    assert_equal 1, result.created_count
    assert_equal 1, result.updated_count
    assert_equal 0, result.deactivated_count
    assert_equal 0, result.rejected_count
    assert_empty result.error_details
    assert_equal "Autor actualizado", cryptics(:mate).reload.author
    imported = Cryptic.find_by!(source_id: "cr-new")
    assert imported.active?
    assert_equal cryptics(:mate).clue, imported.clue
    assert_equal "MATE", imported.answer
    assert_equal [ "cama tejida" ], imported.material
    assert_equal "oculta", imported.puzzle_type
    assert_equal "facil", imported.difficulty
  end

  test "rejects invalid entries individually and preserves rejected local cryptics" do
    cryptics(:mate).update!(active: false)
    mate_before = cryptics(:mate).attributes
    @catalog["cripticos"] = [
      @mate.merge("enumeracion" => "(99)"),
      @camisa,
      @mate.merge("id" => "cr-bad-format", "respuesta" => 123),
      @mate.merge("id" => "cr-bad-list", "material" => [ nil ]),
      @mate.merge("id" => "cr-valid")
    ]

    result = synchronize

    assert_equal "success", result.status
    assert_equal 1, result.created_count
    assert_equal 3, result.rejected_count
    assert_equal 0, result.deactivated_count
    assert_equal %w[cr-001 cr-bad-format cr-bad-list], result.reload.error_details.map { |detail| detail.fetch("source_id") }
    assert result.error_details.all? { |detail| detail.fetch("messages").any? }
    assert_equal mate_before, cryptics(:mate).reload.attributes
    assert_not Cryptic.exists?(source_id: "cr-bad-format")
    assert_not Cryptic.exists?(source_id: "cr-bad-list")
  end

  test "deactivates absent cryptics without deleting games and reactivates returning entries" do
    game = Game.create!(player: players(:newbie), cryptic: cryptics(:camisa))
    @catalog["cripticos"] = [ @mate ]

    result = synchronize
    assert_equal 1, result.deactivated_count
    assert_not cryptics(:camisa).reload.active?
    assert_equal game.cryptic_id, game.reload.cryptic_id

    @catalog["version"] = "v2"
    result = synchronize
    assert_equal 0, result.deactivated_count

    @catalog["version"] = "v3"
    @catalog["cripticos"] << @camisa
    result = synchronize
    assert_equal 1, result.updated_count
    assert cryptics(:camisa).reload.active?
    assert Game.exists?(game.id)
  end

  test "skips the last successful version and records unchanged with zero counts" do
    synchronize
    @catalog["cripticos"][0] = @mate.merge("autor" => "No aplicar")
    before = Cryptic.order(:id).map(&:attributes)

    result = synchronize

    assert_equal "unchanged", result.status
    assert_equal [ 0, 0, 0, 0 ],
      result.attributes.values_at("created_count", "updated_count", "deactivated_count", "rejected_count")
    assert_equal before, Cryptic.order(:id).map(&:attributes)
    assert_equal 2, CatalogSync.count
  end

  test "compares the latest successful version for the requested source only" do
    CatalogSync.create!(source_url: "https://other.example.com/catalog.json", version: "v1", status: "success")
    result = synchronize
    assert_equal "success", result.status

    @catalog["version"] = "v2"
    synchronize
    @catalog["version"] = "v1"
    result = synchronize
    assert_equal "success", result.status
  end

  test "a new version with identical entries does not count or rewrite unchanged cryptics" do
    synchronize
    before = Cryptic.order(:id).map(&:attributes)
    @catalog["version"] = "v2"

    result = synchronize

    assert_equal "success", result.status
    assert_equal 0, result.created_count
    assert_equal 0, result.updated_count
    assert_equal before, Cryptic.order(:id).map(&:attributes)
  end

  test "fails empty catalogs and invalid IDs without changing cryptics" do
    [ [], [ nil ], [ @mate.except("id") ], [ @mate.merge("id" => 1) ] ].each do |entries|
      @catalog["cripticos"] = entries
      before = Cryptic.order(:id).map(&:attributes)

      result = synchronize

      assert_equal "failed", result.status
      assert_equal "v1", result.version
      assert_equal 0, result.created_count
      assert_equal 0, result.deactivated_count
      assert_nil result.error_details.first.fetch("source_id")
      assert result.error_details.first.fetch("messages").any?
      assert_equal before, Cryptic.order(:id).map(&:attributes)
    end
  end

    test "rejects every duplicate entry while processing other entries and preserving local duplicates" do
      mate_before = cryptics(:mate).attributes
      @catalog["cripticos"] = [
        @mate.merge("autor" => "Primera copia"),
        @mate.merge("autor" => "Segunda copia"),
        @mate.merge("id" => "cr-new", "autor" => "Nueva"),
        @mate.merge("id" => "cr-new", "autor" => "Duplicada"),
        @camisa.merge("autor" => "Actualizada"),
        @mate.merge("id" => "cr-invalid", "enumeracion" => "(99)")
      ]

      result = synchronize

      assert_equal "success", result.status
      assert_equal 5, result.rejected_count
      assert_equal 1, result.updated_count
      assert_equal 0, result.created_count
      assert_equal 0, result.deactivated_count
      assert_equal mate_before, cryptics(:mate).reload.attributes
      assert_not Cryptic.exists?(source_id: "cr-new")
      assert_equal "Actualizada", cryptics(:camisa).reload.author
      assert_equal %w[cr-001 cr-001 cr-new cr-new cr-invalid],
        result.reload.error_details.map { |detail| detail.fetch("source_id") }
      assert_equal [ I18n.t("catalog.errors.duplicate_source_id") ],
        result.error_details.first.fetch("messages")
    end

  test "records download failures without changes and permits retrying that version" do
    before = Cryptic.order(:id).map(&:attributes)
    failure = ->(**) { raise Catalog::Download::Error.new(:invalid_json) }

    result = Catalog::Download.stub(:call, failure) do
      Catalog::Synchronize.call(source_url: @source_url)
    end

    assert_equal "failed", result.status
    assert_nil result.version
    assert_equal before, Cryptic.order(:id).map(&:attributes)
    assert_equal I18n.t("catalog.errors.invalid_json"), result.error_details.first.fetch("messages").first
    assert_equal "success", synchronize.status
  end

  test "rejects editor execution before downloading or writing" do
    download = ->(**) { flunk "An editor must not trigger a download" }
    assert_no_difference [ "Cryptic.count", "CatalogSync.count" ] do
      Catalog::Download.stub(:call, download) do
        assert_raises(ActiveRecord::RecordInvalid) do
          Catalog::Synchronize.call(source_url: @source_url, user: users(:two))
        end
      end
    end
  end

  test "rolls back all changes if a database operation fails unexpectedly" do
    @catalog["cripticos"] = [ @mate.merge("id" => "cr-new1"), @mate.merge("id" => "cr-new2") ]
    original = Cryptic.method(:find_or_initialize_by)
    finder = ->(**attributes) {
      raise ActiveRecord::StatementInvalid, "Database failure" if attributes[:source_id] == "cr-new2"
      original.call(**attributes)
    }
    before = Cryptic.order(:id).map(&:attributes)

    assert_no_difference [ "Cryptic.count", "CatalogSync.count" ] do
      Cryptic.stub(:find_or_initialize_by, finder) do
        assert_raises(ActiveRecord::StatementInvalid) { synchronize }
      end
    end
    assert_equal before, Cryptic.order(:id).map(&:attributes)
  end

  private
    def entry_for(cryptic)
      { "id" => cryptic.source_id }.merge(
        Catalog::Synchronize::FIELD_MAPPING.to_h { |source, target| [ source, cryptic.public_send(target) ] }
      )
    end

    def synchronize(user: nil)
      download = ->(source_url:) {
        assert_equal @source_url, source_url
        @catalog
      }
      Catalog::Download.stub(:call, download) do
        Catalog::Synchronize.call(source_url: @source_url, user: user)
      end
    end
end
