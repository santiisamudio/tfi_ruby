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

  test "enumeration counts accented letters and ignores whitespace" do
    [ "JAM\u00D3N", "JAMO\u0301N", " A\u00D1O NUEVO ", "A\u00D1O\tNUEVO" ].each do |answer|
      @cryptic.answer = answer
      @cryptic.enumeration = answer.include?("NUEVO") ? "(8)" : "(5)"

      assert @cryptic.valid?, @cryptic.errors.full_messages.join(", ")
    end
  end

  test "rejects enumeration with incorrect answer length" do
    @cryptic.enumeration = "(5)"

    assert_not @cryptic.valid?
    assert @cryptic.errors.of_kind?(:enumeration, :answer_length_mismatch)
  end

  test "rejects malformed and nonpositive enumerations" do
    [ "6", "(0)", "(-6)", "(06)", "(6.0)", "(6) extra", "(6)\n" ].each do |enumeration|
      @cryptic.enumeration = enumeration

      assert_not @cryptic.valid?
      assert @cryptic.errors.of_kind?(:enumeration, :invalid)
      assert_not @cryptic.errors.of_kind?(:enumeration, :answer_length_mismatch)
    end
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

  test "rejects any fragment missing from the clue and identifies it" do
    %i[definitions indicators material].each do |attribute|
      cryptic = @cryptic.dup
      cryptic.public_send("#{attribute}=", cryptic.public_send(attribute) + [ "no aparece" ])

      assert_not cryptic.valid?
      assert cryptic.errors.of_kind?(attribute, :fragment_missing)
      assert_includes cryptic.errors[attribute].join, "no aparece"
    end
  end

  test "fragment matching preserves case and accents" do
    @cryptic.clue = "Mi metido en el hogar da una prenda de algodón"

    [ "mi", "algodon" ].each do |fragment|
      @cryptic.material = [ fragment ]

      assert_not @cryptic.valid?
      assert @cryptic.errors.of_kind?(:material, :fragment_missing)
    end

    @cryptic.material = [ "Mi", "algodón" ]
    assert @cryptic.valid?
  end

  test "double definition accepts two definitions and rejects other counts" do
    @cryptic.assign_attributes(
      clue: "Asiento de plaza y entidad financiera",
      answer: "BANCO",
      enumeration: "(5)",
      puzzle_type: "doble_definicion",
      definitions: [ "Asiento de plaza", "entidad financiera" ],
      indicators: [],
      material: []
    )

    assert @cryptic.valid?, @cryptic.errors.full_messages.join(", ")
    @cryptic.save!

    [ [], [ "Asiento de plaza" ], [ "Asiento", "de plaza", "entidad financiera" ] ].each do |definitions|
      @cryptic.definitions = definitions

      assert_not @cryptic.valid?
      assert @cryptic.errors.of_kind?(:definitions, :double_definition_count)
      assert_raises(ActiveRecord::StatementInvalid) do
        @cryptic.update_columns(definitions: definitions)
      end
    end
  end

  test "double definition reports malformed definitions without raising" do
    @cryptic.assign_attributes(puzzle_type: "doble_definicion", definitions: nil)

    assert_not @cryptic.valid?
    assert @cryptic.errors.of_kind?(:definitions, :invalid_text_list)
  end

  test "validates the material operation for each required puzzle type" do
    [
      [ "oculta", [ "cama tejida" ], "MATE", "META" ],
      [ "anagrama", [ "Monja" ], "JAM\u00D3N", "MONJE" ],
      [ "iniciales", [ "ocho sapos observan" ], "OSO", "OSA" ],
      [ "finales", [ "\u00E1lbum, casa y amor" ], "MAR", "MAS" ]
    ].each do |type, material, correct, incorrect|
      @cryptic.assign_attributes(
        puzzle_type: type, material: material, clue: material.join(" "),
        definitions: [], indicators: [],
        answer: correct, enumeration: "(#{correct.length})"
      )

      assert @cryptic.valid?, @cryptic.errors.full_messages.join(", ")
      assert_equal material, @cryptic.material

      @cryptic.answer = incorrect
      assert_not @cryptic.valid?
      assert @cryptic.errors.of_kind?(:material, :"#{type}_mismatch")
    end
  end

  test "anagram checks repeated letters rather than only unique letters" do
    @cryptic.assign_attributes(
      puzzle_type: "anagrama", clue: "CASA", material: [ "CASA" ],
      definitions: [], indicators: [], answer: "CASS", enumeration: "(4)"
    )

    assert_not @cryptic.valid?
    assert @cryptic.errors.of_kind?(:material, :anagrama_mismatch)
  end

  test "initials and finals use all fragments and ignore only standalone y" do
    @cryptic.assign_attributes(
      puzzle_type: "iniciales", clue: "Ocho y sapos, observan",
      material: [ "Ocho y", "sapos, observan" ],
      definitions: [], indicators: [], answer: "OSO", enumeration: "(3)"
    )
    assert @cryptic.valid?

    @cryptic.assign_attributes(
      clue: "Yegua e iguana", material: [ "Yegua e iguana" ],
      answer: "YEI", enumeration: "(3)"
    )
    assert @cryptic.valid?

    @cryptic.assign_attributes(
      puzzle_type: "finales", clue: "rey y buey",
      material: [ "rey y buey" ], answer: "YY", enumeration: "(2)"
    )
    assert @cryptic.valid?
  end

  test "material operations preserve enye and reject missing or malformed material" do
    %w[oculta anagrama iniciales finales].each do |type|
      @cryptic.assign_attributes(
        puzzle_type: type, clue: "N", material: [ "N" ],
        definitions: [], indicators: [], answer: "\u00D1", enumeration: "(1)"
      )
      assert_not @cryptic.valid?
      assert @cryptic.errors.of_kind?(:material, :"#{type}_mismatch")

      @cryptic.material = []
      assert_not @cryptic.valid?
      assert @cryptic.errors.of_kind?(:material, :"#{type}_mismatch")

      @cryptic.material = nil
      assert_not @cryptic.valid?
      assert @cryptic.errors.of_kind?(:material, :invalid_text_list)
    end
  end

  test "oculta spans fragments but does not treat y as a connector" do
    @cryptic.assign_attributes(
      puzzle_type: "oculta", clue: "caMA TEjida",
      material: [ "caMA", "TEjida" ], definitions: [], indicators: [],
      answer: "MATE", enumeration: "(4)"
    )
    assert @cryptic.valid?

    @cryptic.assign_attributes(clue: "caMA y TEjida", material: [ "caMA y TEjida" ])
    assert_not @cryptic.valid?
    assert @cryptic.errors.of_kind?(:material, :oculta_mismatch)
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
