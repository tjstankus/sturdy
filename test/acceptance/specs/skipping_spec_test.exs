defmodule Sturdy.Acceptance.SkippingSpecTest do
  use Sturdy.AcceptanceCase

  setup %{sturdy: s} do
    s |> given_it_is("2026-11-10 08:00") |> given_movement("Squat")
    :ok
  end

  test "skipping a set leaves the rest of the plan pending", %{sturdy: s} do
    s
    |> plan("Squat", sets: 3, reps: 5)
    |> skip("Squat")
    |> expect_day("Squat", pending: 2, skipped: 1)
  end

  test "skipping is final: a skipped set can only be deleted", %{sturdy: s} do
    s
    |> plan("Squat", reps: 5)
    |> skip("Squat")
    |> expect_actions("Squat", :skipped, [:delete])
  end

  test "a pending set can be done, changed, skipped, or deleted", %{sturdy: s} do
    s
    |> plan("Squat", reps: 5)
    |> expect_actions("Squat", :pending, [:mark_done, :edit, :skip, :delete])
  end
end
