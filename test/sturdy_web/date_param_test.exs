defmodule SturdyWeb.DateParamTest do
  use ExUnit.Case, async: true

  alias Sturdy.LocalTime
  alias SturdyWeb.DateParam

  test "fetch/1 parses the date param or defaults to today" do
    assert DateParam.fetch(%{"date" => "2026-11-14"}) == {:ok, ~D[2026-11-14]}
    assert DateParam.fetch(%{"date" => "someday"}) == :error
    assert DateParam.fetch(%{}) == {:ok, LocalTime.today()}
  end

  test "label/1 is relative near today" do
    today = LocalTime.today()
    assert DateParam.label(today) == "Today"
    assert DateParam.label(Date.add(today, -1)) == "Yesterday"
    assert DateParam.label(Date.add(today, 1)) == "Tomorrow"
    assert DateParam.label(~D[2020-02-01]) == "Sat, Feb 1"
  end
end
