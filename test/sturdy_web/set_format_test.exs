defmodule SturdyWeb.SetFormatTest do
  use ExUnit.Case, async: true

  alias Sturdy.Training.CompletedSet
  alias Sturdy.Training.PlannedSet
  alias SturdyWeb.SetFormat

  test "summary/1 joins the present measurements" do
    assert SetFormat.summary(%PlannedSet{reps: 5, weight_lb: Decimal.new("100.00")}) ==
             "5 reps · 100 lb"

    assert SetFormat.summary(%CompletedSet{
             duration_s: 30,
             weight_lb: Decimal.new(50),
             side: :left
           }) ==
             "30s · 50 lb · L"

    assert SetFormat.summary(%CompletedSet{distance_m: 40, side: :right}) == "40 m · R"
  end

  test "reps" do
    assert SetFormat.reps(1) == "1 rep"
    assert SetFormat.reps(nil) == nil
  end

  test "duration" do
    assert SetFormat.duration(45) == "45s"
    assert SetFormat.duration(60) == "1:00"
    assert SetFormat.duration(95) == "1:35"
  end

  test "weight shows bodyweight and assistance" do
    assert SetFormat.weight(Decimal.new(0)) == "BW"
    assert SetFormat.weight(Decimal.new("-40")) == "−40 lb"
    assert SetFormat.weight(Decimal.new("22.5")) == "22.5 lb"
  end
end
