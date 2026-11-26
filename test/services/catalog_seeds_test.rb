require "test_helper"
require "minitest/mock"

class CatalogSeedsTest < ActiveSupport::TestCase
  test "loads the catalog as seeds and repeated execution does not duplicate cryptics" do
    mate = cryptics(:mate)
    entry = { "id" => "cr-seed" }.merge(
      Catalog::Synchronize::FIELD_MAPPING.to_h { |source, target| [ source, mate.public_send(target) ] }
    )
    catalog = {
      "version" => "seed-v1", "generado" => "2026-11-26", "fuente" => "Prueba",
      "cripticos" => [ entry ]
    }
    Catalog::Download.stub(:call, catalog) do
      output, errors = capture_io do
        assert_difference "Cryptic.count", 1 do
          load Rails.root.join("db", "seeds.rb")
        end
      end
      assert_includes output, "Creados: 1"
      assert_empty errors
      sync = CatalogSync.order(:id).last
      assert_equal "success", sync.status
      assert_nil sync.user

      output, errors = capture_io do
        assert_no_difference "Cryptic.count" do
          load Rails.root.join("db", "seeds.rb")
        end
      end
      assert_includes output, "Sin cambios"
      assert_empty errors
      assert_equal "unchanged", CatalogSync.order(:id).last.status
    end
  end

  test "prints individual rejections without failing the valid import" do
    catalog = {
      "version" => "seed-v1", "generado" => "2026-11-26", "fuente" => "Prueba",
      "cripticos" => [ { "id" => "cr-invalid" } ]
    }
    Catalog::Download.stub(:call, catalog) do
      output, errors = capture_io { load Rails.root.join("db", "seeds.rb") }

      assert_includes output, "Rechazados: 1".downcase
      assert_includes errors, "cr-invalid:"
      assert_equal "success", CatalogSync.order(:id).last.status
    end
  end

  test "reports download failure and exits unsuccessfully without changing cryptics" do
    failure = ->(**) { raise Catalog::Download::Error.new(:timeout) }
    Catalog::Download.stub(:call, failure) do
      output, errors = capture_io do
        assert_no_difference "Cryptic.count" do
          error = assert_raises(SystemExit) { load Rails.root.join("db", "seeds.rb") }
          assert_not error.success?
        end
      end

      assert_includes output, I18n.t("catalog.sync_results.failed")
      assert_includes errors, I18n.t("catalog.errors.timeout")
      assert_includes errors, I18n.t("catalog.seed_failed")
      assert_equal "failed", CatalogSync.order(:id).last.status
    end
  end
end
