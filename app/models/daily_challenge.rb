class DailyChallenge < ApplicationRecord
  belongs_to :cryptic
  has_many :games, dependent: :restrict_with_error

  validates :date, presence: true, uniqueness: true
end
