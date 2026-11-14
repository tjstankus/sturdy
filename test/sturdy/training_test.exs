defmodule Sturdy.TrainingTest do
  use Sturdy.DataCase, async: true

  import Sturdy.CatalogFixtures
  import Sturdy.TrainingFixtures

  alias Sturdy.Catalog
  alias Sturdy.Training
  alias Sturdy.Training.CompletedSet
  alias Sturdy.Training.PlannedSet
  alias Sturdy.Training.Schedule

  describe "schedule_planned_sets/2" do
    test "bench 3×5 across a three-day range creates nine independent plans" do
      bench = movement_fixture()

      assert {:ok, sets} =
               Training.schedule_planned_sets(
                 %{"movement_id" => bench.id, "reps" => "5", "weight_lb" => "100"},
                 %{"copies" => "3", "range_from" => "2026-11-10", "range_to" => "2026-11-12"}
               )

      assert length(sets) == 9
      assert Enum.all?(sets, &match?(%PlannedSet{status: :pending, reps: 5}, &1))
      assert sets |> Enum.map(& &1.planned_on) |> Enum.uniq() |> length() == 3
      assert Repo.aggregate(PlannedSet, :count) == 9
    end

    test "returns the schedule's changeset when the schedule is invalid" do
      assert {:error, %Ecto.Changeset{data: %Schedule{}}} =
               Training.schedule_planned_sets(%{movement_id: movement_fixture().id, reps: 5}, %{})
    end

    test "returns the template's changeset when the plan is invalid" do
      assert {:error, %Ecto.Changeset{data: %PlannedSet{}} = changeset} =
               Training.schedule_planned_sets(%{movement_id: movement_fixture().id}, %{
                 dates: ["2026-11-10"]
               })

      assert %{reps: [_]} = errors_on(changeset)
    end

    test "inserts nothing when the movement does not exist" do
      assert {:error, changeset} =
               Training.schedule_planned_sets(%{movement_id: -1, reps: 5}, %{
                 copies: 2,
                 dates: ["2026-11-10"]
               })

      assert %{movement: ["does not exist"]} = errors_on(changeset)
      assert Repo.aggregate(PlannedSet, :count) == 0
    end
  end

  describe "completing a plan" do
    test "creates a completed set pre-filled from the plan, making the plan done" do
      plan = planned_set_fixture(%{reps: 5, weight_lb: 100, side: :left})

      assert {:ok, %CompletedSet{} = done} =
               Training.complete_planned_set(plan, ~U[2026-11-10 15:00:00Z])

      assert %{planned_set_id: id, reps: 5, side: :left} = done
      assert id == plan.id
      assert PlannedSet.state(Training.get_planned_set!(plan.id)) == :done
    end

    test "defaults completed_at to now" do
      {:ok, done} = Training.complete_planned_set(planned_set_fixture())
      assert DateTime.diff(DateTime.utc_now(), done.completed_at) < 5
    end

    test "a plan can be completed only once" do
      plan = planned_set_fixture()
      {:ok, _} = Training.complete_planned_set(plan)

      assert {:error, changeset} = Training.complete_planned_set(plan)
      assert %{planned_set_id: ["is already done"]} = errors_on(changeset)
    end

    test "the reality can then be edited, but not the movement or side" do
      plan = planned_set_fixture(%{reps: 5})
      {:ok, done} = Training.complete_planned_set(plan)

      assert {:ok, edited} =
               Training.update_completed_set(done, %{reps: 4, movement_id: movement_fixture().id})

      assert edited.reps == 4
      assert edited.movement_id == plan.movement_id
    end

    test "deleting the completion makes the plan pending again" do
      plan = planned_set_fixture()
      {:ok, done} = Training.complete_planned_set(plan)

      assert {:ok, _} = Training.delete_completed_set(done)
      assert PlannedSet.state(Training.get_planned_set!(plan.id)) == :pending
    end
  end

  describe "skipping" do
    test "is final: a skipped plan cannot be completed, edited, or re-skipped" do
      plan = planned_set_fixture()
      assert {:ok, %{status: :skipped}} = Training.skip_planned_set(plan)

      assert {:error, cs} = Training.complete_planned_set(plan)
      assert %{planned_set_id: ["is already skipped"]} = errors_on(cs)
      assert {:error, cs} = Training.update_planned_set(plan, %{reps: 3})
      assert %{status: ["is already skipped"]} = errors_on(cs)
      assert {:error, _} = Training.skip_planned_set(plan)
    end

    test "a done plan cannot be skipped" do
      plan = planned_set_fixture()
      {:ok, _} = Training.complete_planned_set(plan)

      assert {:error, cs} = Training.skip_planned_set(plan)
      assert %{status: ["is already done"]} = errors_on(cs)
    end
  end

  describe "planned set CRUD" do
    test "a pending plan can be edited and rescheduled" do
      plan = planned_set_fixture()

      assert {:ok, %{reps: 3, planned_on: ~D[2026-11-12]}} =
               Training.update_planned_set(plan, %{reps: 3, planned_on: "2026-11-12"})
    end

    test "a pending plan can be deleted (e.g. to substitute another movement)" do
      plan = planned_set_fixture()
      assert {:ok, _} = Training.delete_planned_set(plan)
      assert_raise Ecto.NoResultsError, fn -> Training.get_planned_set!(plan.id) end
    end

    test "a completed plan cannot be deleted" do
      plan = planned_set_fixture()
      {:ok, _} = Training.complete_planned_set(plan)

      assert {:error, changeset} = Training.delete_planned_set(plan)
      assert %{planned_set: ["has been completed"]} = errors_on(changeset)
    end

    test "change_planned_set/2 returns a changeset" do
      assert %Ecto.Changeset{} = Training.change_planned_set(%PlannedSet{})
    end
  end

  describe "unplanned completed sets" do
    test "can be created, fetched, edited (including movement and side), and deleted" do
      hold = completed_set_fixture(%{reps: nil, duration_s: 30, side: :left})
      other = movement_fixture()

      assert %CompletedSet{movement: %{}, planned_set: nil} = Training.get_completed_set!(hold.id)

      assert {:ok, %{movement_id: movement_id, side: :right}} =
               Training.update_completed_set(hold, %{movement_id: other.id, side: "right"})

      assert movement_id == other.id
      assert {:ok, _} = Training.delete_completed_set(hold)
      assert %Ecto.Changeset{} = Training.change_completed_set(%CompletedSet{})
    end

    test "a set needs some measure" do
      assert {:error, changeset} =
               Training.create_completed_set(%{
                 movement_id: movement_fixture().id,
                 completed_at: ~U[2026-11-10 15:00:00Z],
                 weight_lb: 50
               })

      assert %{reps: ["enter reps, duration, or distance"]} = errors_on(changeset)
    end
  end

  describe "day_of/1 and recent_completed_sets/2" do
    test "a completed plan belongs to its plan's day; unplanned work to its local date" do
      plan = planned_set_fixture(%{planned_on: ~D[2026-11-10]})
      {:ok, done} = Training.complete_planned_set(plan, ~U[2026-11-11 15:00:00Z])
      unplanned = completed_set_fixture(%{completed_at: ~U[2026-11-12 04:30:00Z]})

      assert Training.day_of(Training.get_completed_set!(done.id)) == ~D[2026-11-10]
      assert Training.day_of(unplanned) == ~D[2026-11-11]
    end

    test "recent completed sets for a movement, newest first" do
      movement = movement_fixture()

      old =
        completed_set_fixture(%{movement_id: movement.id, completed_at: ~U[2026-11-01 12:00:00Z]})

      new =
        completed_set_fixture(%{movement_id: movement.id, completed_at: ~U[2026-11-09 12:00:00Z]})

      completed_set_fixture()

      assert Enum.map(Training.recent_completed_sets(movement.id), & &1.id) == [new.id, old.id]
      assert [_] = Training.recent_completed_sets(movement.id, 1)
    end
  end

  describe "movement deletion is restricted by training history" do
    test "a movement with planned sets cannot be deleted" do
      plan = planned_set_fixture()
      assert {:error, changeset} = Catalog.delete_movement(plan.movement)
      assert %{movement: ["has planned sets"]} = errors_on(changeset)
    end

    test "a movement with completed sets cannot be deleted" do
      completed = completed_set_fixture() |> Repo.preload(:movement)
      assert {:error, changeset} = Catalog.delete_movement(completed.movement)
      assert %{movement: ["has completed sets"]} = errors_on(changeset)
    end
  end
end
