class Cryptic < ApplicationRecord
  PUZZLE_TYPES = %w[
    anagrama oculta charada contenedor inversion supresion homofono
    doble_definicion iniciales finales sustitucion simbolos combinada
  ].freeze
  DIFFICULTIES = %w[facil medio avanzado].freeze

  validates :source_id, presence: true, uniqueness: true
  validates :clue, :enumeration, :answer, presence: true
  validates :puzzle_type, inclusion: { in: PUZZLE_TYPES }
  validates :difficulty, inclusion: { in: DIFFICULTIES }
  validates :active, inclusion: { in: [ true, false ] }

  validate :fragments_are_text_lists

  scope :active, -> { where(active: true) }
  scope :with_difficulty, ->(difficulty) { where(difficulty: difficulty) }

  private
    def fragments_are_text_lists
      %i[definitions indicators material].each do |attribute|
        fragments = public_send(attribute)

        unless fragments.is_a?(Array) && fragments.all? { |fragment| fragment.is_a?(String) && fragment.present? }
          errors.add(attribute, :invalid_text_list)
        end
      end
    end
end
