class AnswerNormalizer
  def self.call(text)
    text.unicode_normalize(:nfc).downcase.tr("áéíóúü", "aeiouu").gsub(/[^a-zñ]/, "")
  end
end
