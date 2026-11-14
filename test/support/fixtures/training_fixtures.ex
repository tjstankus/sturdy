defmodule Sturdy.TrainingFixtures do
  @moduledoc """
  Test helpers for creating training records.
  """

  import Sturdy.CatalogFixtures

  alias Sturdy.Training
  alias Sturdy.Training.CompletedSet
  alias Sturdy.Training.PlannedSet

  @doc "One pending planned set (defaults: 5 reps, a new movement, 2026-11-10)."
  @spec planned_set_fixture(map()) :: PlannedSet.t()
  def planned_set_fixture(attrs \\ %{}) do
    {planned_on, attrs} = Map.pop(attrs, :planned_on, ~D[2026-11-10])

    {:ok, [planned_set]} =
      attrs
      |> Enum.into(%{reps: 5})
      |> Map.put_new_lazy(:movement_id, fn -> movement_fixture().id end)
      |> Training.schedule_planned_sets(%{dates: [planned_on]})

    Training.get_planned_set!(planned_set.id)
  end

  @doc "One unplanned completed set."
  @spec completed_set_fixture(map()) :: CompletedSet.t()
  def completed_set_fixture(attrs \\ %{}) do
    {:ok, completed_set} =
      attrs
      |> Enum.into(%{reps: 5, completed_at: ~U[2026-11-10 15:00:00Z]})
      |> Map.put_new_lazy(:movement_id, fn -> movement_fixture().id end)
      |> Training.create_completed_set()

    completed_set
  end
end
