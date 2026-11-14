defmodule Sturdy.Training.CompletedSetTest do
  use ExUnit.Case, async: true

  import Sturdy.DataCase, only: [errors_on: 1]

  alias Sturdy.Training.CompletedSet
  alias Sturdy.Training.PlannedSet

  @plan %PlannedSet{
    id: 7,
    movement_id: 3,
    planned_on: ~D[2026-11-10],
    side: :left,
    reps: 8,
    weight_lb: Decimal.new(25),
    notes: "slow eccentric",
    completed_set: nil
  }

  @at ~U[2026-11-10 15:00:00Z]

  describe "from_plan_changeset/2" do
    test "pre-fills from the plan, except notes" do
      changeset = CompletedSet.from_plan_changeset(@plan, @at)
      assert changeset.valid?

      completed = Ecto.Changeset.apply_changes(changeset)

      assert %{planned_set_id: 7, movement_id: 3, side: :left, reps: 8, completed_at: @at} =
               completed

      assert completed.weight_lb == Decimal.new(25)
      assert completed.notes == nil
    end

    test "rejects a plan that is not pending" do
      assert %{planned_set_id: ["is already skipped"]} =
               errors_on(CompletedSet.from_plan_changeset(%{@plan | status: :skipped}, @at))
    end
  end

  describe "changeset/2" do
    test "an unplanned set can change movement and side" do
      changeset =
        CompletedSet.changeset(%CompletedSet{}, %{
          movement_id: 3,
          side: "right",
          reps: 5,
          completed_at: @at
        })

      assert changeset.valid?
      assert %{movement_id: 3, side: :right} = changeset.changes
    end

    test "a completed plan keeps its movement and side but its numbers are editable" do
      linked = @plan |> CompletedSet.from_plan_changeset(@at) |> Ecto.Changeset.apply_changes()

      changeset =
        CompletedSet.changeset(linked, %{movement_id: 99, side: "right", reps: 7, notes: "tired"})

      assert changeset.changes == %{reps: 7, notes: "tired"}
    end

    test "requires movement, time, and a measure" do
      errors = errors_on(CompletedSet.changeset(%CompletedSet{}, %{}))
      assert errors.movement_id == ["can't be blank"]
      assert errors.completed_at == ["can't be blank"]
      assert errors.reps == ["enter reps, duration, or distance"]
    end
  end
end
