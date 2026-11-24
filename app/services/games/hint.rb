class Games::Hint
  def self.call(player:, game_id:, level:)
    Games::DailyExpiration.call(player: player)

    player.with_lock do
      raise Game::ActionError.new(:blocked_player) if player.blocked?

      game = player.games.find(game_id)
      Games::DailyExpiration.ensure_current!(game)
      raise Game::ActionError.new(:not_started) if game.status == "pending"
      raise Game::ActionError.new(:finished_game) unless game.status == "in_progress"
      unless level.is_a?(Integer) && (1..4).cover?(level)
        raise Game::ActionError.new(:invalid_hint_level)
      end
      if level > game.hints_count + 1
        raise Game::ActionError.new(:hint_out_of_order)
      end

      cryptic = game.cryptic
      payload = case level
      when 1
        { level: level, puzzle_type: cryptic.puzzle_type }
      when 2
        { level: level, definitions: cryptic.definitions }
      when 3
        { level: level, indicators: cryptic.indicators, material: cryptic.material }
      when 4
        raise Game::ActionError.new(:missing_hint) if cryptic.hint.blank?
        { level: level, hint: cryptic.hint }
      end

      game.update!(hints_count: level) if level > game.hints_count
      payload
    end
  end
end
