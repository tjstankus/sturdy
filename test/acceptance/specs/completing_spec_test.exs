defmodule Sturdy.Acceptance.CompletingSpecTest do
  use Sturdy.AcceptanceCase

  setup %{sturdy: s} do
    s |> given_it_is("2026-11-10 08:00") |> given_movement("Push-up")
    :ok
  end

  test "marking a planned set done records it now, and the day shows progress", %{sturdy: s} do
    s
    |> plan("Push-up", sets: 3, reps: 12)
    |> given_it_is("2026-11-10 09:15")
    |> mark_done("Push-up")
    |> expect_day("Push-up", done: 1, pending: 2)
    |> expect_done("Push-up", summary: "12 reps", at: "09:15", unplanned: false)
  end

  test "what really happened can differ from the plan, which stays visible", %{sturdy: s} do
    s
    |> plan("Push-up", reps: 12)
    |> mark_done("Push-up")
    |> record_actual("Push-up", reps: 10, at: "today 07:30")
    |> expect_done("Push-up", summary: "10 reps", planned: "12 reps", at: "07:30")
  end

  test "undoing a done set returns its plan to pending", %{sturdy: s} do
    s
    |> plan("Push-up", sets: 2, reps: 12)
    |> mark_done("Push-up")
    |> undo("Push-up")
    |> expect_day("Push-up", pending: 2)
  end

  test "a done plan can be corrected or undone, but not deleted", %{sturdy: s} do
    s
    |> plan("Push-up", reps: 12)
    |> mark_done("Push-up")
    |> expect_actions("Push-up", :done, [:edit, :undo])
  end

  test "a plan done late still belongs to the day it was planned for", %{sturdy: s} do
    s
    |> plan("Push-up", reps: 12)
    |> given_it_is("2026-11-11 07:00")
    |> mark_done("Push-up", on: "yesterday")
    |> expect_day("Push-up", done: 1, on: "yesterday")
    |> expect_nothing_on("today")
  end
end
