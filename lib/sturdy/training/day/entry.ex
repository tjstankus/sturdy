defmodule Sturdy.Training.Day.Entry do
  @moduledoc """
  One line in the day view: a planned set (pending, done, or skipped) or an
  unplanned completed set (always done).

  `sort_key` orders entries within a movement: done sets chronologically,
  then pending plans, then skipped plans (each in planning order).
  `active_at` is when the entry entered the day — the completion time for done
  sets, the planning time otherwise — and orders movement groups.
  """

  alias Sturdy.Catalog.Movement
  alias Sturdy.Training.CompletedSet
  alias Sturdy.Training.PlannedSet

  @type sort_key :: {0..2, integer()}

  @type t :: %__MODULE__{
          state: PlannedSet.state(),
          movement: Movement.t(),
          planned_set: PlannedSet.t() | nil,
          completed_set: CompletedSet.t() | nil,
          sort_key: sort_key(),
          active_at: DateTime.t()
        }

  @enforce_keys [:state, :movement, :sort_key, :active_at]
  defstruct [:state, :movement, :planned_set, :completed_set, :sort_key, :active_at]

  @doc "Requires `:movement` and `:completed_set` preloaded."
  @spec from_planned(PlannedSet.t()) :: t()
  def from_planned(%PlannedSet{} = planned_set) do
    build(PlannedSet.state(planned_set), planned_set, planned_set.completed_set)
  end

  @doc "Requires `:movement` preloaded."
  @spec from_unplanned(CompletedSet.t()) :: t()
  def from_unplanned(%CompletedSet{planned_set_id: nil} = completed_set) do
    build(:done, nil, completed_set)
  end

  defp build(:done, planned_set, completed_set) do
    %__MODULE__{
      state: :done,
      movement: completed_set.movement || planned_set.movement,
      planned_set: planned_set,
      completed_set: completed_set,
      sort_key: {0, DateTime.to_unix(completed_set.completed_at)},
      active_at: completed_set.completed_at
    }
  end

  defp build(state, planned_set, nil) when state in [:pending, :skipped] do
    rank = %{pending: 1, skipped: 2}

    %__MODULE__{
      state: state,
      movement: planned_set.movement,
      planned_set: planned_set,
      sort_key: {Map.fetch!(rank, state), planned_set.id},
      active_at: planned_set.inserted_at
    }
  end
end
