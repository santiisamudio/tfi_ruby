module ChatbotNodesHelper
  CHATBOT_TAGS = %w[ mark span strong em ].freeze

  def chatbot_text(paragraph)
    sanitize(paragraph, tags: CHATBOT_TAGS, attributes: %w[ class ])
  end
end
