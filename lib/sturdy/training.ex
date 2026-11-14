defmodule Sturdy.Training do
  @moduledoc """
  Planning and recording sets.
  """

  import Ecto.Query, only: [from: 2]

  alias Ecto.Changeset
  alias Ecto.Multi
  alias Sturdy.Repo
  alias Sturdy.Training.CompletedSet
  alias Sturdy.Training.Day
  alias Sturdy.Training.PlannedSet
  alias Sturdy.Training.Schedule

  @type result(t) :: {:ok, t} | {:error, Changeset.t()}

  @doc "See `Sturdy.Training.Day.for_date/1`."
  @spec day(Date.t()) :: [Day.group()]
  defdelegate day(date), to: Day, as: :for_date

  @doc "See `Sturdy.Training.Day.date_of/1`."
  @spec day_of(CompletedSet.t()) :: Date.t()
  defdelegate day_of(completed_set), to: Day, as: :date_of

  @doc "A movement's most recent completed sets, newest first."
  @spec recent_completed_sets(integer(), pos_integer()) :: [CompletedSet.t()]
  def recent_completed_sets(movement_id, limit \\ 20) do
    Repo.all(
      from c in CompletedSet,
        where: c.movement_id == ^movement_id,
        order_by: [desc: c.completed_at, desc: c.id],
        limit: ^limit
    )
  end

  # Planned sets

  @doc "A planned set with its movement and completion preloaded."
  @spec get_planned_set!(integer() | String.t()) :: PlannedSet.t()
  def get_planned_set!(id) do
    Repo.one!(from p in PlannedSet, where: p.id == ^id, preload: [:movement, :completed_set])
  end

  @spec change_planned_set(PlannedSet.t(), map()) :: Changeset.t()
  def change_planned_set(%PlannedSet{} = planned_set, attrs \\ %{}) do
    PlannedSet.changeset(planned_set, attrs)
  end

  @doc "A changeset for scheduling options, for forms."
  @spec change_schedule(map()) :: Changeset.t()
  def change_schedule(attrs \\ %{}), do: Schedule.changeset(%Schedule{}, attrs)

  @doc "How many planned sets the schedule in a changeset would create."
  @spec schedule_set_count(Changeset.t()) :: non_neg_integer()
  def schedule_set_count(%Changeset{data: %Schedule{}} = changeset),
    do: changeset |> Changeset.apply_changes() |> Schedule.set_count()

  @doc """
  Plans sets from one template (`plan_attrs`, without a date) and a schedule
  (`schedule_attrs`, see `Sturdy.Training.Schedule`). All or nothing.

  On error the changeset is either the schedule's (`%Schedule{}` data) or the
  template's (`%PlannedSet{}` data).
  """
  @spec schedule_planned_sets(map(), map()) :: result([PlannedSet.t()])
  def schedule_planned_sets(plan_attrs, schedule_attrs) do
    insert_each = fn planned_sets ->
      planned_sets
      |> Enum.with_index()
      |> Enum.reduce(Multi.new(), fn {planned_set, index}, multi ->
        Multi.insert(multi, index, PlannedSet.changeset(planned_set, %{}))
      end)
      |> Repo.transaction()
    end

    with {:ok, schedule} <- Schedule.new(schedule_attrs),
         first_date = schedule |> Schedule.dates() |> hd(),
         {:ok, template} <-
           %PlannedSet{planned_on: first_date}
           |> PlannedSet.changeset(plan_attrs)
           |> Changeset.apply_action(:insert),
         {:ok, inserted} <- schedule |> Schedule.expand(template) |> insert_each.() do
      {:ok, inserted |> Enum.sort() |> Enum.map(fn {_index, planned_set} -> planned_set end)}
    else
      {:error, _index, changeset, _done} -> {:error, changeset}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc "Edits a pending plan (done and skipped plans are history)."
  @spec update_planned_set(PlannedSet.t(), map()) :: result(PlannedSet.t())
  def update_planned_set(%PlannedSet{} = planned_set, attrs) do
    planned_set
    |> current()
    |> PlannedSet.update_changeset(attrs)
    |> Repo.update()
  end

  @doc "Skips a pending plan. Skipping is final."
  @spec skip_planned_set(PlannedSet.t()) :: result(PlannedSet.t())
  def skip_planned_set(%PlannedSet{} = planned_set) do
    planned_set
    |> current()
    |> PlannedSet.skip_changeset()
    |> Repo.update()
  end

  @doc "Deletes a plan, unless it has been completed."
  @spec delete_planned_set(PlannedSet.t()) :: result(PlannedSet.t())
  def delete_planned_set(%PlannedSet{} = planned_set) do
    planned_set
    |> PlannedSet.delete_changeset()
    |> Repo.delete()
  end

  @doc """
  Marks a pending plan done by recording a completed set pre-filled from it.
  Edit the result with `update_completed_set/2` if reality differed.
  """
  @spec complete_planned_set(PlannedSet.t(), DateTime.t()) :: result(CompletedSet.t())
  def complete_planned_set(%PlannedSet{} = planned_set, completed_at \\ DateTime.utc_now(:second)) do
    planned_set
    |> current()
    |> CompletedSet.from_plan_changeset(completed_at)
    |> Repo.insert()
  end

  # Completed sets

  @spec get_completed_set!(integer() | String.t()) :: CompletedSet.t()
  def get_completed_set!(id) do
    Repo.one!(from c in CompletedSet, where: c.id == ^id, preload: [:movement, :planned_set])
  end

  @spec change_completed_set(CompletedSet.t(), map()) :: Changeset.t()
  def change_completed_set(%CompletedSet{} = completed_set, attrs \\ %{}) do
    CompletedSet.changeset(completed_set, attrs)
  end

  @doc "Records unplanned work."
  @spec create_completed_set(map()) :: result(CompletedSet.t())
  def create_completed_set(attrs), do: save_completed_set(%CompletedSet{}, attrs)

  @spec update_completed_set(CompletedSet.t(), map()) :: result(CompletedSet.t())
  def update_completed_set(%CompletedSet{} = completed_set, attrs),
    do: save_completed_set(completed_set, attrs)

  @doc "Inserts new unplanned work or updates a loaded completed set."
  @spec save_completed_set(CompletedSet.t(), map()) :: result(CompletedSet.t())
  def save_completed_set(%CompletedSet{} = completed_set, attrs) do
    completed_set
    |> CompletedSet.changeset(attrs)
    |> Repo.insert_or_update()
  end

  @doc "Deletes a completed set. A plan it completed becomes pending again."
  @spec delete_completed_set(CompletedSet.t()) :: result(CompletedSet.t())
  def delete_completed_set(%CompletedSet{} = completed_set), do: Repo.delete(completed_set)

  # State rules must see the stored plan, not a possibly stale struct held by the caller.
  defp current(%PlannedSet{id: id}), do: get_planned_set!(id)
end
