defmodule Sturdy.Training.PlannedSetTest do
  use ExUnit.Case, async: true

  import Sturdy.DataCase, only: [errors_on: 1]

  alias Sturdy.Training.CompletedSet
  alias Sturdy.Training.PlannedSet

  @pending %PlannedSet{
    id: 1,
    movement_id: 1,
    planned_on: ~D[2026-11-10],
    reps: 5,
    completed_set: nil
  }

  describe "state/1" do
    test "pending, skipped, and done (derived from a completion)" do
      assert PlannedSet.state(@pending) == :pending
      assert PlannedSet.state(%{@pending | status: :skipped}) == :skipped
      assert PlannedSet.state(%{@pending | completed_set: %CompletedSet{}}) == :done
    end
  end

  describe "changeset/2" do
    test "requires a movement and a date" do
      errors = errors_on(PlannedSet.changeset(%PlannedSet{}, %{reps: 5}))
      assert errors.movement_id == ["can't be blank"]
      assert errors.planned_on == ["can't be blank"]
    end

    test "never casts status" do
      changeset = PlannedSet.changeset(@pending, %{status: "skipped"})
      refute Ecto.Changeset.changed?(changeset, :status)
    end

    test "validates metrics" do
      assert %{reps: [_]} = errors_on(PlannedSet.changeset(%{@pending | reps: nil}, %{}))
    end
  end

  describe "update_changeset/2 and skip_changeset/1" do
    test "a pending plan can be edited and skipped" do
      assert PlannedSet.update_changeset(@pending, %{reps: 6}).valid?
      assert %{changes: %{status: :skipped}, valid?: true} = PlannedSet.skip_changeset(@pending)
    end

    test "done and skipped plans cannot be edited or skipped" do
      for {plan, state} <- [
            {%{@pending | completed_set: %CompletedSet{}}, "done"},
            {%{@pending | status: :skipped}, "skipped"}
          ] do
        assert %{status: ["is already " <> ^state]} =
                 errors_on(PlannedSet.update_changeset(plan, %{reps: 6}))

        assert %{status: ["is already " <> ^state]} = errors_on(PlannedSet.skip_changeset(plan))
      end
    end
  end

  test "validate_pending/3 puts the error on the given field" do
    done = %{@pending | completed_set: %CompletedSet{}}

    changeset =
      PlannedSet.validate_pending(Ecto.Changeset.change(%CompletedSet{}), done, :planned_set_id)

    assert %{planned_set_id: ["is already done"]} = errors_on(changeset)
  end
end
