defmodule Sturdy.Body.BodyweightEntry do
  @moduledoc """
  Bodyweight on a date (at most one entry per day), in pounds. Lets the
  effective load of bodyweight-relative sets be computed later.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          measured_on: Date.t() | nil,
          weight_lb: Decimal.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "bodyweight_entries" do
    field :measured_on, :date
    field :weight_lb, :decimal

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:measured_on, :weight_lb])
    |> validate_required([:measured_on, :weight_lb])
    |> validate_number(:weight_lb, greater_than: 0, less_than: 1000)
    |> unique_constraint(:measured_on, message: "already has an entry")
  end
end
