class Player < ApplicationRecord
  NAME_LENGTH = 3..20

  has_secure_token

  before_validation :normalize_name

  validates :name, presence: true, length: { in: NAME_LENGTH, allow_blank: true }
  validates :normalized_name, uniqueness: true
  validates :current_streak, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :best_streak, numericality: { only_integer: true, greater_than_or_equal_to: :current_streak }

  scope :not_blocked, -> { where(blocked_at: nil) }

  def self.name_taken?(name)
    exists?(normalized_name: name.strip.downcase)
  end

  def self.suggest_name(name)
    number = 2
    candidate = name_with_number(name, number)
    while name_taken?(candidate)
      number += 1
      candidate = name_with_number(name, number)
    end
    candidate
  end

  def self.name_with_number(name, number)
    suffix = "_#{number}"
    base = name.strip[0, NAME_LENGTH.max - suffix.length]
    base.rstrip + suffix
  end
  private_class_method :name_with_number

  def name_suggestion
    if errors.of_kind?(:normalized_name, :taken)
      Player.suggest_name(name)
    end
  end

  def blocked?
    blocked_at.present?
  end

  def active_streak(today = Date.current)
    if streak_alive?(today)
      current_streak
    else
      0
    end
  end

  def streak_alive?(today = Date.current)
    last_streak_on.present? && last_streak_on >= today.yesterday
  end

  def streak_counted_today?(today = Date.current)
    last_streak_on == today
  end

  def streak_dates(today = Date.current)
    return [] unless streak_alive?(today) && current_streak > 0

    first_day = last_streak_on - (current_streak - 1)
    (first_day..last_streak_on).to_a
  end

  private
    def normalize_name
      if name
        self.name = name.strip
        self.normalized_name = name.downcase
      end
    end
end
