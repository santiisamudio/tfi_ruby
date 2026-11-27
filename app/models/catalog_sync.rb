class CatalogSync < ApplicationRecord
  belongs_to :user, optional: true

  STATUSES = %w[success unchanged failed].freeze

  validates :source_url, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :version, presence: true, if: -> { status.in?(%w[success unchanged]) }
  validates :created_count, :updated_count, :deactivated_count, :rejected_count,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :executor_is_admin
  validate :error_details_are_message_lists

  private
    def executor_is_admin
      errors.add(:user, :admin_required) if user && !user.admin?
    end

    def error_details_are_message_lists
      valid = error_details.is_a?(Array) && error_details.all? do |detail|
        detail.is_a?(Hash) &&
          detail.keys.sort == %w[messages source_id] &&
          (detail["source_id"].nil? || (detail["source_id"].is_a?(String) && detail["source_id"].present?)) &&
          detail["messages"].is_a?(Array) && detail["messages"].any? &&
          detail["messages"].all? { |message| message.is_a?(String) && message.present? }
      end
      errors.add(:error_details, :invalid_sync_details) unless valid
    end
end
