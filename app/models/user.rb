class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :catalog_syncs, dependent: :restrict_with_error

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  ROLES = %w[admin editor].freeze

  validates :role, inclusion: { in: ROLES }

  def admin?
    role == "admin"
  end

  def editor?
    role == "editor"
  end
end
