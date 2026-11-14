defmodule Sturdy.Training.PlannedSet do
  @moduledoc """
  One intended set of a movement on a date ("3×5" is three planned sets).

  A plan's state is derived, never stored as "done": a plan is `:done` exactly
  when a `CompletedSet` links to it. The stored `status` records intent only
  (`:pending` or `:skipped`), and skipping is final.

  Functions that inspect state (`state/1`, `validate_pending/3`, and the
  changesets built on them) require `:completed_set` to be preloaded.
  """

  use Ecto.Schema

  import Ecto.Changeset

  require Sturdy.Training.SetMetrics

  alias Sturdy.Catalog.Movement
  alias Sturdy.Training.CompletedSet
  alias Sturdy.Training.SetMetrics

  @type status :: :pending | :skipped
  @type state :: :pending | :done | :skipped

  @type t :: %__MODULE__{
          id: integer() | nil,
          movement_id: integer() | nil,
          movement: Movement.t() | Ecto.Association.NotLoaded.t() | nil,
          planned_on: Date.t() | nil,
          status: status(),
          side: SetMetrics.side(),
          reps: pos_integer() | nil,
          duration_s: pos_integer() | nil,
          distance_m: pos_integer() | nil,
          weight_lb: Decimal.t() | nil,
          notes: String.t() | nil,
          completed_set: CompletedSet.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "planned_sets" do
    field :planned_on, :date
    field :status, Ecto.Enum, values: [:pending, :skipped], default: :pending

    SetMetrics.schema_fields()

    belongs_to :movement, Movement
    has_one :completed_set, CompletedSet

    timestamps(type: :utc_datetime)
  end

  @doc """
  Builds a new plan. `status` is never cast; only `skip_changeset/1` changes it.
  """
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(planned_set, attrs) do
    planned_set
    |> cast(attrs, [:movement_id, :planned_on | SetMetrics.fields()])
    |> validate_required([:movement_id, :planned_on])
    |> SetMetrics.validate()
    |> assoc_constraint(:movement)
  end

  @doc """
  Edits an existing plan. Only pending plans are editable; done and skipped
  plans are history.
  """
  @spec update_changeset(t(), map()) :: Ecto.Changeset.t()
  def update_changeset(planned_set, attrs) do
    planned_set
    |> changeset(attrs)
    |> validate_pending(planned_set)
  end

  @spec skip_changeset(t()) :: Ecto.Changeset.t()
  def skip_changeset(planned_set) do
    planned_set
    |> change(status: :skipped)
    |> validate_pending(planned_set)
  end

  @doc """
  A completed plan cannot be deleted (delete its completed set first).
  """
  @spec delete_changeset(t()) :: Ecto.Changeset.t()
  def delete_changeset(planned_set) do
    planned_set
    |> change()
    |> foreign_key_constraint(:planned_set,
      name: :completed_sets_planned_set_id_fkey,
      message: "has been completed"
    )
  end

  @spec state(t()) :: state()
  def state(%__MODULE__{completed_set: %CompletedSet{}}), do: :done
  def state(%__MODULE__{completed_set: nil, status: status}), do: status

  @doc """
  Adds an error to `changeset` (on `field`) unless the plan is pending.
  """
  @spec validate_pending(Ecto.Changeset.t(), t(), atom()) :: Ecto.Changeset.t()
  def validate_pending(changeset, planned_set, field \\ :status) do
    case state(planned_set) do
      :pending -> changeset
      state -> add_error(changeset, field, "is already #{state}")
    end
  end
end
