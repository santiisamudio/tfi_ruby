class Game < ApplicationRecord
  class ActionError < StandardError
    attr_reader :code

    def initialize(code)
      @code = code
      super(I18n.t("games.errors.#{code}", raise: true))
    end
  end

  STATUSES = %w[pending in_progress won lost surrendered expired].freeze
  OPEN_STATUSES = %w[pending in_progress].freeze

  belongs_to :player
  belongs_to :cryptic
  belongs_to :daily_challenge, optional: true

  validates :status, inclusion: { in: STATUSES }
  validates :attempts_count, numericality: { only_integer: true, in: 0..5 }
  validates :hints_count, numericality: { only_integer: true, in: 0..4 }
  validates :points, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :player_id, uniqueness: {
    conditions: -> { where(status: OPEN_STATUSES) }, message: :open_game_exists
  }, if: -> { OPEN_STATUSES.include?(status) }
  validates :cryptic_id, uniqueness: {
    scope: :player_id, conditions: -> { where.not(started_at: nil) }, message: :already_played
  }, if: -> { started_at.present? }
  validates :daily_challenge_id, uniqueness: { scope: :player_id }, allow_nil: true

  validate :state_is_consistent
  validate :timestamps_are_ordered
  validate :daily_challenge_is_consistent

  scope :open, -> { where(status: OPEN_STATUSES) }

  private
    def state_is_consistent
      return unless STATUSES.include?(status)

      consistent = case status
      when "pending"
        started_at.nil? && finished_at.nil? && points.nil? && attempts_count == 0 && hints_count == 0
      when "in_progress"
        started_at.present? && finished_at.nil? && points.nil? && (0..4).cover?(attempts_count)
      when "won"
        started_at.present? && finished_at.present? && points.is_a?(Integer) && points >= 10 &&
          (1..5).cover?(attempts_count)
      when "lost"
        started_at.present? && finished_at.present? && points == 0 && attempts_count == 5
      when "surrendered"
        started_at.present? && finished_at.present? && points == 0 && (0..4).cover?(attempts_count)
      when "expired"
        daily_challenge.present? && finished_at.present? && points == 0 &&
          (started_at.present? || (attempts_count == 0 && hints_count == 0))
      end

      errors.add(:base, :inconsistent_state) unless consistent
    end

    def timestamps_are_ordered
      if started_at && finished_at && finished_at < started_at
        errors.add(:finished_at, :before_start)
      end
    end

    def daily_challenge_is_consistent
      return unless daily_challenge

      if cryptic_id != daily_challenge.cryptic_id
        errors.add(:cryptic, :daily_mismatch)
      end
      return unless daily_challenge.date

      if started_at && started_at.to_date != daily_challenge.date
        errors.add(:started_at, :outside_daily_date)
      end
      if finished_at
        if status == "expired"
          errors.add(:finished_at, :before_expiration) if finished_at.to_date <= daily_challenge.date
        elsif finished_at.to_date != daily_challenge.date
          errors.add(:finished_at, :outside_daily_date)
        end
      end
    end
end
