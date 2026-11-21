require "test_helper"

class CrypticTest < ActiveSupport::TestCase
  setup do
    @cryptic = Cryptic.new(
      source_id: "cr-013",
      clue: "Mi metido en el hogar da una prenda",
      enumeration: "(6)",
      answer: "CAMISA",
      definitions: [ "una prenda" ],
      indicators: [ "metido en" ],
      material: [ "Mi", "el hogar" ],
      puzzle_type: "contenedor",
      difficulty: "medio",
      hint: "Parti el hogar al medio y mete MI.",
      explanation: "CA + MI + SA = CAMISA.",
      author: "Catedra"
    )
  end

  test "persists catalog fields and queries active cryptics by difficulty" do
    @cryptic.save!
    inactive = @cryptic.dup
    inactive.update!(source_id: "cr-inactive", active: false)
    easy = @cryptic.dup
    easy.update!(source_id: "cr-easy", difficulty: "facil")

    assert_equal [ @cryptic ], Cryptic.active.with_difficulty("medio").to_a
    assert_equal [ "Mi", "el hogar" ], @cryptic.reload.material
  end

  test "requires identity and playable text" do
    %i[source_id clue enumeration answer].each do |attribute|
      cryptic = @cryptic.dup
      cryptic.public_send("#{attribute}=", " ")

      assert_not cryptic.valid?
      assert cryptic.errors.of_kind?(attribute, :blank)
    end
  end

  test "rejects duplicate source identifiers in model and database" do
    @cryptic.save!
    duplicate = @cryptic.dup

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:source_id, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "rejects unknown puzzle types and difficulties" do
    @cryptic.puzzle_type = "otro"
    @cryptic.difficulty = "dificil"

    assert_not @cryptic.valid?
    assert @cryptic.errors.of_kind?(:puzzle_type, :inclusion)
    assert @cryptic.errors.of_kind?(:difficulty, :inclusion)
  end

  test "requires fragment arrays containing only nonblank strings" do
    %i[definitions indicators material].each do |attribute|
      [ nil, "texto", { "fragmento" => "texto" }, [ 1 ], [ "" ], [ " " ] ].each do |value|
        cryptic = @cryptic.dup
        cryptic.public_send("#{attribute}=", value)

        assert_not cryptic.valid?
        assert cryptic.errors.of_kind?(attribute, :invalid_text_list)
      end
    end
  end

  test "allows empty fragment arrays and inactive cryptics" do
    @cryptic.assign_attributes(
      definitions: [], indicators: [], material: [], active: false
    )

    assert @cryptic.valid?
    @cryptic.active = nil
    assert_not @cryptic.valid?
    assert @cryptic.errors.of_kind?(:active, :inclusion)
  end

  test "database rejects invalid catalog fields when model validations are bypassed" do
    @cryptic.save!

    {
      clue: "",
      answer: nil,
      puzzle_type: "otro",
      difficulty: "dificil",
      definitions: "no es una lista",
      indicators: { "texto" => "metido en" },
      material: nil
    }.each do |attribute, value|
      assert_raises(ActiveRecord::StatementInvalid) do
        @cryptic.update_columns(attribute => value)
      end
    end
  end
end
