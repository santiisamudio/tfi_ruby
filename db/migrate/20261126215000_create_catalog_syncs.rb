class CreateCatalogSyncs < ActiveRecord::Migration[8.1]
  def change
    create_table :catalog_syncs do |t|
      t.references :user, foreign_key: true
      t.string :source_url, null: false
      t.string :version
      t.string :status, null: false
      t.integer :created_count, null: false, default: 0
      t.integer :updated_count, null: false, default: 0
      t.integer :deactivated_count, null: false, default: 0
      t.integer :rejected_count, null: false, default: 0
      t.json :error_details, null: false, default: []
      t.timestamps
    end

    add_check_constraint :catalog_syncs, "length(trim(source_url)) > 0",
      name: "catalog_syncs_source_url_not_empty"
    add_check_constraint :catalog_syncs, "status IN ('success', 'unchanged', 'failed')",
      name: "catalog_syncs_status_allowed"
    add_check_constraint :catalog_syncs,
      "status = 'failed' OR (version IS NOT NULL AND length(trim(version)) > 0)",
      name: "catalog_syncs_completed_version"
    %w[created_count updated_count deactivated_count rejected_count].each do |column|
      add_check_constraint :catalog_syncs, "#{column} >= 0",
        name: "catalog_syncs_#{column}_not_negative"
    end
    add_check_constraint :catalog_syncs,
      "CASE WHEN json_valid(error_details) THEN json_type(error_details) = 'array' ELSE 0 END",
      name: "catalog_syncs_error_details_array"
  end
end
