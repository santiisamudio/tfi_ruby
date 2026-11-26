class Catalog::Synchronize
  FIELD_MAPPING = {
    "enunciado" => :clue,
    "enumeracion" => :enumeration,
    "respuesta" => :answer,
    "definiciones" => :definitions,
    "indicadores" => :indicators,
    "material" => :material,
    "tipo" => :puzzle_type,
    "dificultad" => :difficulty,
    "ayuda" => :hint,
    "explicacion" => :explanation,
    "autor" => :author
  }.freeze
  LIST_FIELDS = %w[definiciones indicadores material].freeze
  OPTIONAL_FIELDS = %w[ayuda explicacion autor].freeze

  def self.call(source_url: Catalog::Download::DEFAULT_SOURCE_URL, user: nil)
    new(source_url: source_url, user: user).call
  end

  def initialize(source_url:, user:)
    @sync = CatalogSync.new(source_url: source_url, user: user, status: "failed")
  end

  def call
    @sync.validate!
    catalog = Catalog::Download.call(source_url: @sync.source_url)
    @sync.version = catalog.fetch("version")
    entries = catalog.fetch("cripticos")
    identity_error = identity_error_for(entries)
    return record_failure(I18n.t("catalog.errors.#{identity_error}", raise: true)) if identity_error

    CatalogSync.transaction do
      # Take the database write lock before checking the last version or changing cryptics.
      @sync.save!
      previous = CatalogSync.where(source_url: @sync.source_url, status: "success")
        .order(created_at: :desc, id: :desc).first
      if previous&.version == @sync.version
        @sync.update!(status: "unchanged")
      else
        entries.each { |entry| import_entry(entry) }
        @sync.deactivated_count = Cryptic.active.where.not(source_id: entries.map { |entry| entry.fetch("id") })
          .update_all(active: false, updated_at: Time.current)
        @sync.update!(status: "success")
      end
    end
    @sync
  rescue Catalog::Download::Error => error
    record_failure(error.message)
  end

  private
    def identity_error_for(entries)
      return :empty_catalog if entries.empty?
      unless entries.all? { |entry| entry.is_a?(Hash) && entry["id"].is_a?(String) && entry["id"].present? }
        return :invalid_source_ids
      end
      ids = entries.map { |entry| entry.fetch("id") }
      :duplicate_source_ids if ids.uniq.length != ids.length
    end

    def import_entry(entry)
      invalid_fields = FIELD_MAPPING.keys.reject { |field| valid_field_format?(field, entry[field]) }
      if invalid_fields.any?
        messages = invalid_fields.map { |field| I18n.t("catalog.errors.invalid_field", field: field, raise: true) }
        reject_entry(entry.fetch("id"), messages)
        return
      end

      cryptic = Cryptic.find_or_initialize_by(source_id: entry.fetch("id"))
      attributes = FIELD_MAPPING.to_h { |source, target| [ target, entry[source] ] }
      cryptic.assign_attributes(attributes.merge(active: true))
      unless cryptic.valid?
        reject_entry(entry.fetch("id"), cryptic.errors.full_messages)
        return
      end
      return unless cryptic.has_changes_to_save?

      counter = cryptic.new_record? ? :created_count : :updated_count
      cryptic.save!
      @sync[counter] += 1
    end

    def valid_field_format?(field, value)
      if LIST_FIELDS.include?(field)
        value.is_a?(Array)
      elsif OPTIONAL_FIELDS.include?(field)
        value.nil? || value.is_a?(String)
      else
        value.is_a?(String)
      end
    end

    def reject_entry(source_id, messages)
      @sync.rejected_count += 1
      @sync.error_details << { "source_id" => source_id, "messages" => messages }
    end

    def record_failure(message)
      @sync.error_details = [ { "source_id" => nil, "messages" => [ message ] } ]
      @sync.save!
      @sync
    end
end
