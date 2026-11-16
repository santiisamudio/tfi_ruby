require "test_helper"

class PlayerTest < ActiveSupport::TestCase
  test "name is unique ignoring case, accents included" do
    assert_not Player.new(name: "PEDRITO").valid?
    assert_not Player.new(name: "ÁNGELA").valid?
    assert Player.new(name: "Angela").valid?
  end
end
