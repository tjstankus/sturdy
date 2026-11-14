defmodule Sturdy.Training.CompletedSet do
  @moduledoc """
  A set that was actually performed. It may complete a `PlannedSet`, or be
  unplanned work (`planned_set_id` is nil).

  A completed plan always matches its plan's movement and side:
  `from_plan_changeset/2` copies them, and `changeset/2` never lets them be
  edited on a linked set.
  """

  use Ecto.Schema

  import Ecto.Changeset

  require Sturdy.Training.SetMetrics

  alias Sturdy.Catalog.Movement
  alias Sturdy.Training.PlannedSet
  alias Sturdy.Training.SetMetrics

  @type t :: %__MODULE__{
          id: integer() | nil,
          movement_id: integer() | nil,
          movement: Movement.t() | Ecto.Association.NotLoaded.t() | nil,
          planned_set_id: integer() | nil,
          planned_set: PlannedSet.t() | Ecto.Association.NotLoaded.t() | nil,
          completed_at: DateTime.t() | nil,
          side: SetMetrics.side(),
          reps: pos_integer() | nil,
          duration_s: pos_integer() | nil,
          distance_m: pos_integer() | nil,
          weight_lb: Decimal.t() | nil,
          notes: String.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "completed_sets" do
    field :completed_at, :utc_datetime

    SetMetrics.schema_fields()

    belongs_to :movement, Movement
    belongs_to :planned_set, PlannedSet

    timestamps(type: :utc_datetime)
  end

  @doc """
  Creates or edits a completed set. `completed_at` is UTC.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(completed_set, attrs) do
    completed_set
    |> cast(attrs, [:completed_at | editable_fields(completed_set)])
    |> validate_required([:movement_id, :completed_at])
    |> SetMetrics.validate()
    |> assoc_constraint(:movement)
  end

  @doc """
  The fields a user may edit: everything on unplanned work; only the
  measurements (not movement or side) on a completed plan.
  """
  @spec editable_fields(t()) :: [atom()]
  def editable_fields(%__MODULE__{planned_set_id: nil}), do: [:movement_id | SetMetrics.fields()]
  def editable_fields(%__MODULE__{}), do: SetMetrics.fields() -- [:side]

  @doc """
  Completes a pending plan: a completed set pre-filled with the plan's movement,
  side, and measurements (not its notes, which record intent). The plan must
  have `:completed_set` preloaded.
  """
  @spec from_plan_changeset(PlannedSet.t(), DateTime.t()) :: Ecto.Changeset.t()
  def from_plan_changeset(%PlannedSet{} = planned_set, completed_at) do
    copied = Map.take(planned_set, [:movement_id | SetMetrics.fields() -- [:notes]])

    __MODULE__
    |> struct(copied)
    |> change(planned_set_id: planned_set.id, completed_at: completed_at)
    |> PlannedSet.validate_pending(planned_set, :planned_set_id)
    |> unique_constraint(:planned_set_id, message: "is already done")
    |> assoc_constraint(:planned_set)
  end
end
