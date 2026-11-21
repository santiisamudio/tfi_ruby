require "test_helper"

class DailyChallengeTest < ActiveSupport::TestCase
  test "allows one shared assignment per date in model and database" do
    DailyChallenge.create!(date: Date.current, cryptic: cryptics(:camisa))
    duplicate = DailyChallenge.new(date: Date.current, cryptic: cryptics(:mate))

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:date, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "requires a date and a cryptic" do
    challenge = DailyChallenge.new

    assert_not challenge.valid?
    assert challenge.errors.of_kind?(:date, :blank)
    assert challenge.errors.of_kind?(:cryptic, :blank)
  end
end
