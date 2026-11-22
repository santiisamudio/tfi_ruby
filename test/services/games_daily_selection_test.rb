require "test_helper"

class GamesDailySelectionTest < ActiveSupport::TestCase
  test "selects deterministically from the source ordered eligible catalog" do
    today = Date.current
    candidates = Cryptic.active.order(:source_id).pluck(:id)
    position = Digest::SHA256.hexdigest(today.iso8601).to_i(16) % candidates.length
    challenge = Games::DailySelection.call

    assert_equal today, challenge.date
    assert_equal candidates.fetch(position), challenge.cryptic_id
    assert_difference "DailyChallenge.count", 0 do
      assert_equal challenge, Games::DailySelection.call
    end
  end

  test "keeps the saved selection even if the active catalog changes" do
    challenge = Games::DailySelection.call
    challenge.cryptic.update!(active: false)

    assert_equal challenge, Games::DailySelection.call
  end

  test "excludes inactive cryptics and ones assigned on previous dates" do
    DailyChallenge.create!(date: Date.current.yesterday, cryptic: cryptics(:camisa))

    challenge = Games::DailySelection.call
    assert_equal cryptics(:mate), challenge.cryptic
  end

  test "does not create another challenge when the eligible catalog is exhausted" do
    DailyChallenge.create!(date: Date.current.yesterday, cryptic: cryptics(:camisa))
    cryptics(:mate).update!(active: false)

    assert_no_difference "DailyChallenge.count" do
      error = assert_raises(Game::ActionError) { Games::DailySelection.call }
      assert_equal :no_daily_cryptics, error.code
    end
  end

  test "different dates select different cryptics until the catalog runs out" do
    original_date = Date.current
    first = Games::DailySelection.call
    travel_to (original_date + 1).in_time_zone + 12.hours do
      second = Games::DailySelection.call
      assert_not_equal first.cryptic_id, second.cryptic_id
    end
    travel_to (original_date + 2).in_time_zone + 12.hours do
      assert_raises(Game::ActionError) { Games::DailySelection.call }
    end
  end
end
