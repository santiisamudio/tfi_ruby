require "test_helper"

class LeaderboardsControllerTest < ActionDispatch::IntegrationTest
  test "lists active streaks without blocked players" do
    get leaderboard_url(tab: "streaks")

    assert_select "tbody tr", count: 2
    assert_select "tbody tr:first-child", text: /Ángela/
    assert_select "tbody", text: /Bloqueado/, count: 0
    assert_select "tbody", text: /Lucía/, count: 0
  end
end
