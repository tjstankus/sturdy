defmodule Sturdy.Training.DayTest do
  # The configured timezone is America/New_York (UTC-5 in November).
  use Sturdy.DataCase, async: true

  import Sturdy.CatalogFixtures
  import Sturdy.TrainingFixtures

  alias Sturdy.Training

  @date ~D[2026-11-10]

  test "an empty day" do
    assert Training.day(@date) == []
  end

  test "groups by movement; within a group: done chronologically, then pending, then skipped" do
    bench = movement_fixture(%{name: "Bench"})
    [first, second, third] = for _ <- 1..3, do: planned_set_fixture(%{movement_id: bench.id})

    {:ok, _} = Training.skip_planned_set(first)
    {:ok, later} = Training.complete_planned_set(third, ~U[2026-11-10 18:00:00Z])

    unplanned =
      completed_set_fixture(%{movement_id: bench.id, completed_at: ~U[2026-11-10 14:00:00Z]})

    assert [%{movement: %{name: "Bench"}, entries: entries}] = Training.day(@date)

    assert Enum.map(entries, &{&1.state, (&1.completed_set || &1.planned_set).id}) == [
             {:done, unplanned.id},
             {:done, later.id},
             {:pending, second.id},
             {:skipped, first.id}
           ]
  end

  test "movement groups are ordered by when each entered the day" do
    planned = planned_set_fixture()

    Repo.update_all(Sturdy.Training.PlannedSet, set: [inserted_at: ~U[2026-11-09 12:00:00Z]])

    ad_hoc = completed_set_fixture(%{completed_at: ~U[2026-11-10 13:00:00Z]})

    assert [first_group, second_group] = Training.day(@date)
    assert first_group.movement.id == planned.movement_id
    assert second_group.movement.id == ad_hoc.movement_id
  end

  test "unplanned sets are placed by local date; 12:30am belongs to the new day" do
    late = completed_set_fixture(%{completed_at: ~U[2026-11-11 04:30:00Z]})
    after_midnight = completed_set_fixture(%{completed_at: ~U[2026-11-11 05:30:00Z]})

    ids = fn date -> for g <- Training.day(date), e <- g.entries, do: e.completed_set.id end

    assert ids.(~D[2026-11-10]) == [late.id]
    assert ids.(~D[2026-11-11]) == [after_midnight.id]
  end

  test "a plan completed the next day stays on its planned day, once" do
    plan = planned_set_fixture(%{planned_on: @date})
    {:ok, _} = Training.complete_planned_set(plan, ~U[2026-11-11 15:00:00Z])

    assert [%{entries: [%{state: :done}]}] = Training.day(@date)
    assert Training.day(~D[2026-11-11]) == []
  end
end
