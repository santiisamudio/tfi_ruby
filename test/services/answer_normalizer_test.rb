require "test_helper"

class AnswerNormalizerTest < ActiveSupport::TestCase
  test "normalizes accents case spaces and punctuation" do
    [ "jamon", " JAM\u00D3N! ", "JAMO\u0301N" ].each do |answer|
      assert_equal "jamon", AnswerNormalizer.call(answer)
    end
    assert_equal "pinguino", AnswerNormalizer.call("PING\u00DCINO")
  end

  test "preserves enye including decomposed input" do
    assert_equal "a\u00F1o", AnswerNormalizer.call("AN\u0303O")
    assert_not_equal AnswerNormalizer.call("ANO"), AnswerNormalizer.call("A\u00D1O")
  end

  test "does not remove conjunctions from answers" do
    assert_equal "y", AnswerNormalizer.call("Y")
    assert_equal "rey", AnswerNormalizer.call("REY")
  end
end
