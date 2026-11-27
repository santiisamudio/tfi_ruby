# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

sync = Catalog::Synchronize.call
puts I18n.t("catalog.sync_results.#{sync.status}", raise: true)
puts I18n.t(
  "catalog.seed_summary",
  created: sync.created_count, updated: sync.updated_count,
  deactivated: sync.deactivated_count, rejected: sync.rejected_count,
  raise: true
)

sync.error_details.each do |detail|
  source_id = detail.fetch("source_id") || I18n.t("catalog.general_error", raise: true)
  detail.fetch("messages").each { |message| warn "#{source_id}: #{message}" }
end

abort I18n.t("catalog.seed_failed", raise: true) if sync.status == "failed"

if Rails.env.development?
  multipliers = { "facil" => 1, "medio" => 2, "avanzado" => 3 }

  seed_players = [
    { name: "Lucía", games: [
      { days_ago: 8, difficulty: "facil", hints: 0, seconds: 45 },
      { days_ago: 7, difficulty: "medio", hints: 1, seconds: 150 },
      { days_ago: 6, difficulty: "avanzado", hints: 0, seconds: 280 },
      { days_ago: 5, difficulty: "facil", hints: 1, seconds: 70 },
      { days_ago: 4, difficulty: "medio", hints: 0, seconds: 200 },
      { days_ago: 3, difficulty: "avanzado", hints: 1, seconds: 420 },
      { days_ago: 2, difficulty: "facil", hints: 0, seconds: 35 },
      { days_ago: 1, difficulty: "medio", hints: 0, seconds: 170 },
      { days_ago: 0, difficulty: "avanzado", hints: 0, seconds: 300 }
    ] },
    { name: "Joaco", games: [
      { days_ago: 12, difficulty: "medio", hints: 0, seconds: 160 },
      { days_ago: 11, difficulty: "medio", hints: 0, seconds: 190 },
      { days_ago: 10, difficulty: "medio", hints: 1, seconds: 240 },
      { days_ago: 9, difficulty: "medio", hints: 0, seconds: 175 },
      { days_ago: 4, difficulty: "avanzado", hints: 0, seconds: 500 },
      { days_ago: 3, difficulty: "avanzado", hints: 0, seconds: 610 },
      { days_ago: 2, difficulty: "avanzado", hints: 0, seconds: 380 },
      { days_ago: 1, difficulty: "avanzado", hints: 0, seconds: 450 },
      { days_ago: 0, difficulty: "avanzado", hints: 0, seconds: 520 }
    ] },
    { name: "Vale", games: [
      { days_ago: 2, difficulty: "facil", hints: 0, seconds: 50 },
      { days_ago: 2, difficulty: "medio", hints: 1, seconds: 260 },
      { days_ago: 1, difficulty: "facil", hints: 0, seconds: 40 },
      { days_ago: 1, difficulty: "medio", hints: 1, seconds: 210 },
      { days_ago: 0, difficulty: "facil", hints: 0, seconds: 55 },
      { days_ago: 0, difficulty: "medio", hints: 1, seconds: 230 }
    ] },
    { name: "Tomi", games: [
      { days_ago: 10, difficulty: "avanzado", hints: 1, seconds: 350 },
      { days_ago: 9, difficulty: "avanzado", hints: 0, seconds: 290 },
      { days_ago: 8, difficulty: "avanzado", hints: 0, seconds: 310 },
      { days_ago: 7, difficulty: "medio", hints: 0, seconds: 120 },
      { days_ago: 6, difficulty: "medio", hints: 1, seconds: 180 },
      { days_ago: 5, difficulty: "avanzado", hints: 0, seconds: 270 },
      { days_ago: 4, difficulty: "medio", hints: 0, seconds: 140 }
    ] },
    { name: "Cami", games: [
      { days_ago: 1, difficulty: "medio", hints: 3, wrong: 2, seconds: 900 },
      { days_ago: 0, difficulty: "medio", hints: 3, wrong: 2, seconds: 840 }
    ] },
    { name: "Agus", games: [
      { days_ago: 6, difficulty: "facil", hints: 0, seconds: 120, result: "surrendered" },
      { days_ago: 5, difficulty: "medio", hints: 2, seconds: 400, result: "lost" },
      { days_ago: 3, difficulty: "facil", hints: 0, wrong: 3, seconds: 95 }
    ] },
    { name: "Roco", blocked: true, games: [
      { days_ago: 2, difficulty: "avanzado", hints: 0, seconds: 200 },
      { days_ago: 1, difficulty: "avanzado", hints: 0, seconds: 210 },
      { days_ago: 0, difficulty: "avanzado", hints: 0, seconds: 190 }
    ] }
  ]

  %w[Bauti Mora Nico Juli Fran Abril Mateo Delfi Thiago Lola Bruno Cata Benja Emma Facu Pili].each_with_index do |name, index|
    seed_players << { name: name, games: [
      { days_ago: 0, difficulty: Cryptic::DIFFICULTIES[index % 3], hints: index % 3, seconds: 40 + index * 30 }
    ] }
  end

  seed_players.each do |data|
    next if Player.name_taken?(data[:name])

    player = Player.create!(name: data[:name])
    data[:games].each_with_index do |game_data, index|
      cryptic = Cryptic.active.with_difficulty(game_data[:difficulty])
        .where.not(id: player.games.select(:cryptic_id)).order(:source_id).first
      finished_at = Time.current - game_data[:days_ago].days - (data[:games].size - index).minutes
      started_at = finished_at - game_data[:seconds].seconds
      wrong = game_data.fetch(:wrong, 0)
      status = game_data.fetch(:result, "won")

      if status == "won"
        streak = StreakUpdater.call(player: player, today: finished_at.to_date)
        points = ScoreCalculator.call(
          type_points: 100,
          difficulty_multiplier: multipliers[game_data[:difficulty]],
          difficulty: game_data[:difficulty],
          duration_seconds: game_data[:seconds],
          hints_count: game_data[:hints],
          streak_days: streak
        )
        attempts = wrong + 1
      elsif status == "lost"
        points = 0
        attempts = 5
      else
        points = 0
        attempts = wrong
      end

      player.games.create!(
        cryptic: cryptic, status: status, started_at: started_at, finished_at: finished_at,
        attempts_count: attempts, hints_count: game_data[:hints], points: points
      )
    end

    if data[:blocked]
      player.update!(blocked_at: Time.current)
    end
  end

  puts "Jugadores de prueba: #{Player.count}. Partidas: #{Game.count}."
end
