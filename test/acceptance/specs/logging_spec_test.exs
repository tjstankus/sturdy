defmodule Sturdy.Acceptance.LoggingSpecTest do
  use Sturdy.AcceptanceCase

  setup %{sturdy: s} do
    s |> given_it_is("2026-11-10 14:35") |> given_movement("Push-up")
    :ok
  end

  test "unplanned work is logged on today, at the current time", %{sturdy: s} do
    s
    |> log("Push-up", reps: 15)
    |> expect_day("Push-up", done: 1)
    |> expect_done("Push-up", summary: "15 reps", at: "14:35", unplanned: true)
  end

  test "work just after midnight belongs to the new day", %{sturdy: s} do
    s
    |> log("Push-up", reps: 15, at: "tomorrow 00:30")
    |> expect_nothing_on("today")
    |> expect_done("Push-up", at: "00:30", on: "tomorrow")
  end

  test "late-evening work stays on that local day", %{sturdy: s} do
    s
    |> given_it_is("2026-11-10 23:15")
    |> log("Push-up", reps: 15)
    |> expect_done("Push-up", at: "23:15")
    |> expect_nothing_on("tomorrow")
  end

  test "logged work sits alongside planned work for the same movement", %{sturdy: s} do
    s
    |> plan("Push-up", sets: 2, reps: 12)
    |> log("Push-up", reps: 15)
    |> expect_day("Push-up", done: 1, pending: 2)
    |> expect_done("Push-up", summary: "15 reps", unplanned: true)
  end

  test "logged work can be deleted outright", %{sturdy: s} do
    s
    |> log("Push-up", reps: 15)
    |> expect_actions("Push-up", :done, [:edit, :delete])
    |> delete_logged("Push-up")
    |> expect_nothing_on("today")
  end
end
