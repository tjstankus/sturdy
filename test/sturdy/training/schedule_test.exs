defmodule Sturdy.Training.ScheduleTest do
  use ExUnit.Case, async: true

  import Sturdy.DataCase, only: [errors_on: 1]

  alias Sturdy.Training.PlannedSet
  alias Sturdy.Training.Schedule

  @template %PlannedSet{movement_id: 1, reps: 5}

  defp schedule!(attrs) do
    {:ok, schedule} = Schedule.new(attrs)
    schedule
  end

  describe "dates/1" do
    test "unions chosen dates with the range, sorted and deduplicated" do
      schedule =
        schedule!(%{
          dates: ["2026-11-20", "2026-11-11"],
          range_from: "2026-11-10",
          range_to: "2026-11-12"
        })

      assert Schedule.dates(schedule) == [
               ~D[2026-11-10],
               ~D[2026-11-11],
               ~D[2026-11-12],
               ~D[2026-11-20]
             ]
    end

    test "a one-day range is fine" do
      assert Schedule.dates(schedule!(%{range_from: "2026-11-10", range_to: "2026-11-10"})) == [
               ~D[2026-11-10]
             ]
    end
  end

  describe "expand/2" do
    test "3 copies on one date" do
      sets = Schedule.expand(schedule!(%{copies: 3, dates: ["2026-11-10"]}), @template)
      assert length(sets) == 3

      assert Enum.all?(
               sets,
               &match?(%PlannedSet{planned_on: ~D[2026-11-10], side: nil, reps: 5}, &1)
             )
    end

    test "per side alternates left and right within each copy, per date" do
      schedule = schedule!(%{copies: 2, per_side: true, dates: ["2026-11-10", "2026-11-11"]})
      sets = Schedule.expand(schedule, @template)

      assert Enum.map(sets, &{&1.planned_on.day, &1.side}) == [
               {10, :left},
               {10, :right},
               {10, :left},
               {10, :right},
               {11, :left},
               {11, :right},
               {11, :left},
               {11, :right}
             ]

      assert Schedule.set_count(schedule) == 8
    end

    test "without per side the template's own side is kept" do
      [set] = Schedule.expand(schedule!(%{dates: ["2026-11-10"]}), %{@template | side: :right})
      assert set.side == :right
    end
  end

  describe "changeset validation" do
    test "needs at least one date" do
      assert {:error, changeset} = Schedule.new(%{})
      assert %{dates: ["pick at least one date"]} = errors_on(changeset)
    end

    test "a range needs both ends, in order" do
      assert {:error, cs} = Schedule.new(%{range_from: "2026-11-10"})
      assert %{range_to: ["is needed to finish the range"]} = errors_on(cs)

      assert {:error, cs} = Schedule.new(%{range_to: "2026-11-10"})
      assert %{range_from: ["is needed to start the range"]} = errors_on(cs)

      assert {:error, cs} = Schedule.new(%{range_from: "2026-11-12", range_to: "2026-11-10"})
      assert %{range_to: ["must be on or after the start"]} = errors_on(cs)
    end

    test "copies are bounded" do
      assert {:error, cs} = Schedule.new(%{copies: 0, dates: ["2026-11-10"]})
      assert %{copies: [_]} = errors_on(cs)
      assert {:error, cs} = Schedule.new(%{copies: 21, dates: ["2026-11-10"]})
      assert %{copies: [_]} = errors_on(cs)
    end

    test "the total number of sets is bounded" do
      assert {:error, cs} =
               Schedule.new(%{
                 copies: 10,
                 per_side: true,
                 range_from: "2026-11-01",
                 range_to: "2026-11-30"
               })

      assert %{dates: ["would create more than 200 sets"]} = errors_on(cs)
    end
  end
end
