defmodule Sturdy.Acceptance.PlanningSpecTest do
  use Sturdy.AcceptanceCase

  setup %{sturdy: s} do
    s
    |> given_it_is("2026-11-10 08:00")
    |> given_movement("Push-up")
    |> given_movement("Side plank")

    :ok
  end

  test "planned sets wait on their day as pending", %{sturdy: s} do
    s
    |> plan("Push-up", sets: 3, reps: 12)
    |> expect_entries("Push-up", pending: "12 reps", pending: "12 reps", pending: "12 reps")
  end

  test "planning each side gives a left and a right set per set", %{sturdy: s} do
    s
    |> plan("Side plank", sets: 2, hold: 30, each_side: true)
    |> expect_entries("Side plank",
      pending: "30s L",
      pending: "30s R",
      pending: "30s L",
      pending: "30s R"
    )
  end

  test "sets can be planned on several chosen days", %{sturdy: s} do
    s
    |> plan("Push-up", reps: 10, on: ["today", "in 2 days"])
    |> expect_day("Push-up", pending: 1)
    |> expect_nothing_on("tomorrow")
    |> expect_day("Push-up", pending: 1, on: "in 2 days")
  end

  test "planning every day in a range covers each day, ends included", %{sturdy: s} do
    s
    |> plan_every_day("Push-up", reps: 10, from: "tomorrow", to: "in 3 days")
    |> expect_nothing_on("today")
    |> expect_day("Push-up", pending: 1, on: "tomorrow")
    |> expect_day("Push-up", pending: 1, on: "in 2 days")
    |> expect_day("Push-up", pending: 1, on: "in 3 days")
    |> expect_nothing_on("in 4 days")
  end

  test "a pending plan can be changed", %{sturdy: s} do
    s
    |> plan("Push-up", reps: 12)
    |> change_plan("Push-up", reps: 8, load: 20)
    |> expect_entries("Push-up", pending: "8 reps 20 lb")
  end

  test "a pending plan can be moved to another day", %{sturdy: s} do
    s
    |> plan("Push-up", sets: 2, reps: 12)
    |> reschedule("Push-up", to: "tomorrow")
    |> expect_day("Push-up", pending: 1)
    |> expect_day("Push-up", pending: 1, on: "tomorrow")
  end
end
