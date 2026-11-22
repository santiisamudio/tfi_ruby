require "digest"

class Games::DailySelection
  def self.call
    DailyChallenge.transaction do
      today = Date.current
      existing = DailyChallenge.find_by(date: today)
      next existing if existing

      eligible_ids = Cryptic.active
        .where.not(id: DailyChallenge.select(:cryptic_id))
        .order(:source_id).pluck(:id)
      raise Game::ActionError.new(:no_daily_cryptics) if eligible_ids.empty?

      position = Digest::SHA256.hexdigest(today.iso8601).to_i(16) % eligible_ids.length
      DailyChallenge.create!(date: today, cryptic_id: eligible_ids.fetch(position))
    end
  end
end
