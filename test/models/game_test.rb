require "test_helper"

class GameTest < ActiveSupport::TestCase
  setup do
    @game = Game.new(player: players(:newbie), cryptic: cryptics(:camisa))
  end

  test "persists a pending game and starts it without scoring" do
    @game.save!
    assert_includes @game.player.games, @game
    assert_includes @game.cryptic.games, @game

    @game.update!(status: "in_progress", started_at: Time.current)
    assert_nil @game.points
    assert_nil @game.finished_at
  end

  test "requires a player and cryptic" do
    game = Game.new

    assert_not game.valid?
    assert game.errors.of_kind?(:player, :blank)
    assert game.errors.of_kind?(:cryptic, :blank)
  end

  test "permits only one open game per player in model and database" do
    @game.save!
    other = Game.new(player: @game.player, cryptic: cryptics(:mate))

    assert_not other.valid?
    assert other.errors.of_kind?(:player_id, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) { other.save!(validate: false) }

    other.player = players(:pedrito)
    assert other.valid?
  end

  test "discarding an unstarted assignment does not consume the cryptic" do
    @game.save!
    @game.destroy!

    replacement = Game.create!(player: players(:newbie), cryptic: cryptics(:camisa))
    assert replacement.persisted?
  end

  test "a started cryptic cannot be replayed by the same player" do
    @game.assign_attributes(
      status: "surrendered", started_at: 1.minute.ago, finished_at: Time.current, points: 0
    )
    @game.save!

    replay = Game.new(
      player: @game.player, cryptic: @game.cryptic,
      status: "in_progress", started_at: Time.current
    )
    assert_not replay.valid?
    assert replay.errors.of_kind?(:cryptic_id, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) { replay.save!(validate: false) }
  end

  test "rejects invalid counters states scores and timestamp order in model and database" do
    @game.save!
    [
      { status: "unknown" },
      { attempts_count: -1 },
      { hints_count: 5 },
      { status: "in_progress", started_at: nil },
      { status: "in_progress", started_at: Time.current, attempts_count: 5 },
      { status: "won", started_at: 1.minute.ago, finished_at: Time.current, attempts_count: 1, points: 9 },
      { status: "lost", started_at: 1.minute.ago, finished_at: Time.current, attempts_count: 4, points: 0 },
      { status: "surrendered", started_at: Time.current, finished_at: 1.minute.ago, points: 0 },
      { status: "expired", finished_at: Time.current, points: 0 }
    ].each do |attributes|
      candidate = @game.dup
      candidate.assign_attributes(attributes)
      assert_not candidate.valid?, attributes.inspect
      assert_raises(ActiveRecord::StatementInvalid) { @game.update_columns(attributes) }
    end
  end

  test "allows winning on the fifth attempt and distinguishes other final outcomes" do
    [
      { status: "won", attempts_count: 5, points: 10 },
      { status: "lost", attempts_count: 5, points: 0 },
      { status: "surrendered", attempts_count: 0, points: 0 }
    ].each do |attributes|
      @game.assign_attributes(
        **attributes, started_at: 1.minute.ago, finished_at: Time.current
      )
      assert @game.valid?, @game.errors.full_messages.join(", ")
    end
  end

  test "daily game must reference its challenge cryptic in model and database" do
    challenge = DailyChallenge.create!(date: Date.current, cryptic: @game.cryptic)
    @game.daily_challenge = challenge
    @game.save!
    assert_includes challenge.games, @game

    @game.cryptic = cryptics(:mate)
    assert_not @game.valid?
    assert @game.errors.of_kind?(:cryptic, :daily_mismatch)
    assert_raises(ActiveRecord::InvalidForeignKey) do
      @game.update_columns(cryptic_id: cryptics(:mate).id)
    end
  end

  test "daily game can finish only during its date or expire afterwards with zero points" do
    challenge = DailyChallenge.create!(date: Date.current.yesterday, cryptic: @game.cryptic)
    @game.assign_attributes(
      daily_challenge: challenge, status: "in_progress",
      started_at: challenge.date.in_time_zone + 12.hours
    )
    assert @game.valid?

    @game.assign_attributes(status: "won", attempts_count: 1, points: 100, finished_at: Time.current)
    assert_not @game.valid?
    assert @game.errors.of_kind?(:finished_at, :outside_daily_date)

    @game.assign_attributes(status: "expired", points: 0)
    @game.save!
    assert_equal 0, @game.reload.points

    @game.points = 10
    assert_not @game.valid?
    @game.assign_attributes(points: 0, finished_at: @game.started_at)
    assert_not @game.valid?
    assert @game.errors.of_kind?(:finished_at, :before_expiration)
  end

  test "unstarted daily assignments can expire without marking the cryptic as played" do
    challenge = DailyChallenge.create!(date: Date.current.yesterday, cryptic: @game.cryptic)
    @game.assign_attributes(
      daily_challenge: challenge, status: "expired", finished_at: Time.current, points: 0
    )
    @game.save!

    assert_nil @game.started_at
    assert Game.new(player: @game.player, cryptic: @game.cryptic).valid?
  end

  test "a player cannot create another daily game after an unstarted daily game expired" do
    challenge = DailyChallenge.create!(date: Date.current.yesterday, cryptic: @game.cryptic)
    @game.assign_attributes(
      daily_challenge: challenge, status: "expired", finished_at: Time.current, points: 0
    )
    @game.save!
    duplicate = Game.new(player: @game.player, cryptic: @game.cryptic, daily_challenge: challenge)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:daily_challenge_id, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "daily game cannot start outside its date" do
    challenge = DailyChallenge.create!(date: Date.current.yesterday, cryptic: @game.cryptic)
    @game.assign_attributes(
      daily_challenge: challenge, status: "in_progress", started_at: Time.current
    )

    assert_not @game.valid?
    assert @game.errors.of_kind?(:started_at, :outside_daily_date)
  end

  test "normal games can finish on a later day and history cannot be deleted with its owner" do
    @game.assign_attributes(
      status: "won", started_at: 2.days.ago, finished_at: Time.current,
      attempts_count: 1, points: 100
    )
    @game.save!

    assert_not @game.player.destroy
    assert_not @game.cryptic.destroy
    assert Game.exists?(@game.id)
  end
end
