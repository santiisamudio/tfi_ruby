class Cryptic < ApplicationRecord
  has_many :games, dependent: :restrict_with_error
  has_many :daily_challenges, dependent: :restrict_with_error

  PUZZLE_TYPES = %w[
    anagrama oculta charada contenedor inversion supresion homofono
    doble_definicion iniciales finales sustitucion simbolos combinada
  ].freeze
  DIFFICULTIES = %w[facil medio avanzado].freeze

  validates :source_id, presence: true, uniqueness: true
  validates :clue, :enumeration, :answer, presence: true
  validates :enumeration, format: { with: /\A\([1-9]\d*\)\z/ }, allow_blank: true
  validates :puzzle_type, inclusion: { in: PUZZLE_TYPES }
  validates :difficulty, inclusion: { in: DIFFICULTIES }
  validates :active, inclusion: { in: [ true, false ] }

  validate :fragments_are_text_lists
  validate :enumeration_matches_answer
  validate :fragments_appear_in_clue
  validate :double_definition_has_two_definitions
  validate :material_matches_answer

  scope :active, -> { where(active: true) }
  scope :with_difficulty, ->(difficulty) { where(difficulty: difficulty) }

  private
    def material_matches_answer
      return unless %w[oculta anagrama iniciales finales].include?(puzzle_type)
      return if answer.blank? || errors.include?(:material)

      normalized_answer = AnswerNormalizer.call(answer)
      if normalized_answer.empty?
        errors.add(:answer, :invalid)
        return
      end

      normalized_material = AnswerNormalizer.call(material.join(" "))
      matches = case puzzle_type
      when "oculta"
        normalized_material.include?(normalized_answer)
      when "anagrama"
        normalized_material.chars.sort == normalized_answer.chars.sort
      when "iniciales", "finales"
        words = material.flat_map { |fragment| fragment.scan(/\p{L}[\p{L}\p{M}]*/) }
          .map { |word| AnswerNormalizer.call(word) }
          .reject { |word| word == "y" }
        index = puzzle_type == "iniciales" ? 0 : -1
        words.map { |word| word[index] }.join == normalized_answer
      end

      errors.add(:material, :"#{puzzle_type}_mismatch") unless matches
    end

    def double_definition_has_two_definitions
      return unless puzzle_type == "doble_definicion" && definitions.is_a?(Array)

      if definitions.length != 2
        errors.add(:definitions, :double_definition_count)
      end
    end

    def fragments_appear_in_clue
      return if clue.blank?

      %i[definitions indicators material].each do |attribute|
        next if errors.include?(attribute)

        public_send(attribute).each do |fragment|
          unless clue.include?(fragment)
            errors.add(attribute, :fragment_missing, fragment: fragment)
          end
        end
      end
    end

    def enumeration_matches_answer
      return if answer.blank? || enumeration.blank? || errors.include?(:enumeration)

      answer_length = answer.gsub(/[[:space:]]/, "").scan(/\X/).length
      expected_length = enumeration[1...-1].to_i

      if answer_length != expected_length
        errors.add(:enumeration, :answer_length_mismatch, count: answer_length)
      end
    end

    def fragments_are_text_lists
      %i[definitions indicators material].each do |attribute|
        fragments = public_send(attribute)

        unless fragments.is_a?(Array) && fragments.all? { |fragment| fragment.is_a?(String) && fragment.present? }
          errors.add(attribute, :invalid_text_list)
        end
      end
    end
end
