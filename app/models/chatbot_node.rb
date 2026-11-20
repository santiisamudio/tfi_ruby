class ChatbotNode
  SOURCE = Rails.root.join("config/chatbot.yml")
  START_ID = "welcome"
  MENU_ID = "menu"

  attr_reader :id, :prompt, :message

  def self.all
    @all ||= load_all
  end

  def self.find(id)
    all[id.to_s]
  end

  def self.start
    find(START_ID)
  end

  def self.load_all
    nodes = {}
    YAML.load_file(SOURCE, aliases: true).each do |id, attributes|
      nodes[id] = ChatbotNode.new(id, attributes)
    end
    nodes
  end
  private_class_method :load_all

  def initialize(id, attributes)
    @id = id
    @prompt = attributes["prompt"]
    @message = attributes["message"]
    @option_ids = attributes["options"] || []
  end

  def options
    ids = @option_ids.dup
    ids << MENU_ID unless menu?
    ids.map { |option_id| ChatbotNode.find(option_id) }
  end

  def paragraphs
    message.split("\n\n").map { |paragraph| paragraph.strip }
  end

  def askable?
    prompt.present?
  end

  def menu?
    id == START_ID || id == MENU_ID
  end
end
