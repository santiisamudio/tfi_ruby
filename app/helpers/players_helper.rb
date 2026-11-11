module PlayersHelper
  def enumeration(text)
    words = text.to_s.split
    return "" if words.empty?

    lengths = words.map { |word| word.length }
    "(#{lengths.join(", ")})"
  end
end
