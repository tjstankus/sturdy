defmodule Sturdy.Training.Day do
  @moduledoc """
  Everything that happened, or is meant to happen, on one local date: the date's
  planned sets plus unplanned completed sets performed that day.

  Written procedurally on purpose. How the day view should be composed is not
  well understood yet, so this stays one plain function until real use shows
  its shape.
  """

  import Ecto.Query

  alias Sturdy.Catalog.Movement
  alias Sturdy.LocalTime
  alias Sturdy.Repo
  alias Sturdy.Training.CompletedSet
  alias Sturdy.Training.Day.Entry
  alias Sturdy.Training.PlannedSet

  @type group :: %{movement: Movement.t(), entries: [Entry.t(), ...]}

  @doc """
  The day a completed set appears on: its plan's date when it completed a plan
  (requires `:planned_set` preloaded), otherwise the local date it happened.
  """
  @spec date_of(CompletedSet.t()) :: Date.t()
  def date_of(%CompletedSet{planned_set_id: nil, completed_at: completed_at}),
    do: LocalTime.date_of(completed_at)

  def date_of(%CompletedSet{planned_set: %PlannedSet{planned_on: planned_on}}), do: planned_on

  @doc """
  The day's entries grouped by movement. Groups are ordered by when each
  movement entered the day; entries within a group by `Entry.sort_key`.
  """
  @spec for_date(Date.t()) :: [group()]
  def for_date(%Date{} = date) do
    {day_start, next_day_start} = LocalTime.day_bounds(date)

    planned =
      Repo.all(
        from p in PlannedSet,
          where: p.planned_on == ^date,
          preload: [:movement, completed_set: :movement]
      )

    unplanned =
      Repo.all(
        from c in CompletedSet,
          where: is_nil(c.planned_set_id),
          where: c.completed_at >= ^day_start and c.completed_at < ^next_day_start,
          preload: :movement
      )

    (Enum.map(planned, &Entry.from_planned/1) ++ Enum.map(unplanned, &Entry.from_unplanned/1))
    |> Enum.group_by(& &1.movement.id)
    |> Enum.map(fn {_movement_id, entries} ->
      %{movement: hd(entries).movement, entries: Enum.sort_by(entries, & &1.sort_key)}
    end)
    |> Enum.sort_by(
      fn group -> group.entries |> Enum.map(& &1.active_at) |> Enum.min(DateTime) end,
      DateTime
    )
  end
end
