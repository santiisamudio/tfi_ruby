require "test_helper"

class ScoreCalculatorTest < ActiveSupport::TestCase
  setup do
    @parameters = {
      type_points: 100, difficulty_multiplier: 2, difficulty: "medio",
      duration_seconds: 240, hints_count: 1, streak_days: 4
    }
  end

  test "matches the requirement examples" do
    assert_equal 144, ScoreCalculator.call(**@parameters)
    assert_equal 240, ScoreCalculator.call(**@parameters, duration_seconds: 120, hints_count: 0)
  end

  test "does not penalize durations up to the reference including zero" do
    { "facil" => 60, "medio" => 180, "avanzado" => 300 }.each do |difficulty, reference|
      [ 0, reference ].each do |duration|
        assert_equal 240, ScoreCalculator.call(
          **@parameters, difficulty: difficulty, duration_seconds: duration, hints_count: 0
        )
      end
    end
  end

  test "time factor bottoms out at one quarter" do
    [ 720, 100_000 ].each do |duration|
      assert_equal 60, ScoreCalculator.call(**@parameters, duration_seconds: duration, hints_count: 0)
    end
  end

  test "each hint reduces the factor by one fifth" do
    [ 240, 192, 144, 96, 48 ].each_with_index do |expected, hints|
      assert_equal expected, ScoreCalculator.call(**@parameters, duration_seconds: 180, hints_count: hints)
    end
  end

  test "streak includes today and caps at ten days" do
    { 1 => 210, 2 => 220, 4 => 240, 10 => 300, 30 => 300 }.each do |days, expected|
      assert_equal expected, ScoreCalculator.call(
        **@parameters, duration_seconds: 180, hints_count: 0, streak_days: days
      )
    end
  end

  test "rounds halves up and applies the ten point minimum to wins" do
    assert_equal 11, ScoreCalculator.call(
      **@parameters, type_points: 10, difficulty_multiplier: 1,
      duration_seconds: 0, hints_count: 0, streak_days: 1
    )
    assert_equal 10, ScoreCalculator.call(
      **@parameters, type_points: 10, difficulty_multiplier: BigDecimal("0.1"),
      duration_seconds: 100_000, hints_count: 4, streak_days: 1
    )
  end

  test "rejects invalid inputs instead of calculating fallback scores" do
    {
      type_points: [ 9, 1001, 100.5 ],
      difficulty_multiplier: [ 0, -1, 5.1, Float::NAN, Float::INFINITY, "2" ],
      difficulty: [ "otra" ],
      duration_seconds: [ -1, Float::INFINITY, nil ],
      hints_count: [ -1, 5, 1.5 ],
      streak_days: [ 0, -1, 1.5 ]
    }.each do |parameter, values|
      values.each do |value|
        assert_raises(ArgumentError) { ScoreCalculator.call(**@parameters.merge(parameter => value)) }
      end
    end
  end
end
