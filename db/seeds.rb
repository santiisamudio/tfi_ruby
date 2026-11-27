# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

sync = Catalog::Synchronize.call
puts I18n.t("catalog.sync_results.#{sync.status}", raise: true)
puts I18n.t(
  "catalog.seed_summary",
  created: sync.created_count, updated: sync.updated_count,
  deactivated: sync.deactivated_count, rejected: sync.rejected_count,
  raise: true
)

sync.error_details.each do |detail|
  source_id = detail.fetch("source_id") || I18n.t("catalog.general_error", raise: true)
  detail.fetch("messages").each { |message| warn "#{source_id}: #{message}" }
end

abort I18n.t("catalog.seed_failed", raise: true) if sync.status == "failed"
