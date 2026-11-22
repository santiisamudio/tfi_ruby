require "uri"

class Games::ShareResult
  def self.call(game)
    unless %w[won lost surrendered expired].include?(game.status) && game.finished_at && !game.points.nil?
      raise Game::ActionError.new(:share_unfinished)
    end

    lines = [ I18n.t("games.share.title", raise: true) ]
    if game.daily_challenge
      lines << I18n.t("games.share.daily", date: game.daily_challenge.date.iso8601, raise: true)
    end
    lines << I18n.t("games.share.statuses.#{game.status}", raise: true)
    lines << I18n.t("games.share.points", points: game.points, raise: true)
    lines << I18n.t("games.share.attempts", attempts: game.attempts_count, raise: true)
    lines << I18n.t("games.share.hints", hints: game.hints_count, raise: true)
    if game.started_at
      seconds = (game.finished_at - game.started_at).to_i
      lines << I18n.t("games.share.time", seconds: seconds, raise: true)
    end

    text = lines.join("\n")
    { text: text, whatsapp_url: "https://wa.me/?#{URI.encode_www_form(text: text)}" }
  end
end
