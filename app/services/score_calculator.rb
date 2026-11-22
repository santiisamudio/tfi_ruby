require "bigdecimal"

class ScoreCalculator
  REFERENCE_SECONDS = { "facil" => 60, "medio" => 180, "avanzado" => 300 }.freeze

  def self.call(type_points:, difficulty_multiplier:, difficulty:, duration_seconds:, hints_count:, streak_days:)
    unless type_points.is_a?(Integer) && (10..1000).cover?(type_points)
      raise ArgumentError, I18n.t("scores.errors.type_points", raise: true)
    end
    unless decimal_number?(difficulty_multiplier) && difficulty_multiplier > 0 && difficulty_multiplier <= 5
      raise ArgumentError, I18n.t("scores.errors.multiplier", raise: true)
    end
    unless REFERENCE_SECONDS.key?(difficulty)
      raise ArgumentError, I18n.t("games.errors.invalid_difficulty", raise: true)
    end
    unless decimal_number?(duration_seconds) && duration_seconds >= 0
      raise ArgumentError, I18n.t("scores.errors.duration", raise: true)
    end
    unless hints_count.is_a?(Integer) && (0..4).cover?(hints_count)
      raise ArgumentError, I18n.t("scores.errors.hints", raise: true)
    end
    unless streak_days.is_a?(Integer) && streak_days >= 1
      raise ArgumentError, I18n.t("scores.errors.streak", raise: true)
    end

    reference = BigDecimal(REFERENCE_SECONDS.fetch(difficulty).to_s)
    duration = BigDecimal(duration_seconds.to_s)
    time_factor = duration <= reference ? BigDecimal("1") : [ reference / duration, BigDecimal("0.25") ].max
    hints_factor = 1 - BigDecimal("0.20") * hints_count
    streak_factor = [ 1 + BigDecimal("0.05") * streak_days, BigDecimal("1.5") ].min
    base = type_points * BigDecimal(difficulty_multiplier.to_s)

    [ (base * time_factor * hints_factor * streak_factor).round(0, :half_up).to_i, 10 ].max
  end

  def self.decimal_number?(value)
    value.is_a?(Integer) || ((value.is_a?(Float) || value.is_a?(BigDecimal)) && value.finite?)
  end
  private_class_method :decimal_number?
end
