defmodule Sturdy.Training.Schedule do
  @moduledoc """
  How to turn one planned-set template into many planned sets: `copies` of it
  on each date, optionally doubled into left and right sides.

  Dates are the union of the explicitly chosen `dates` and the inclusive
  `range_from`..`range_to` range; either or both may be given.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Sturdy.Training.PlannedSet
  alias Sturdy.Training.SetMetrics

  @max_copies 20
  @max_sets 200

  @type t :: %__MODULE__{
          copies: pos_integer(),
          per_side: boolean(),
          dates: [Date.t()],
          range_from: Date.t() | nil,
          range_to: Date.t() | nil
        }

  @primary_key false
  embedded_schema do
    field :copies, :integer, default: 1
    field :per_side, :boolean, default: false
    field :dates, {:array, :date}, default: []
    field :range_from, :date
    field :range_to, :date
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(schedule, attrs) do
    range_error = fn
      nil, nil -> nil
      _from, nil -> {:range_to, "is needed to finish the range"}
      nil, _to -> {:range_from, "is needed to start the range"}
      from, to -> Date.after?(from, to) && {:range_to, "must be on or after the start"}
    end

    validate_range = fn changeset ->
      case range_error.(get_field(changeset, :range_from), get_field(changeset, :range_to)) do
        {field, message} -> add_error(changeset, field, message)
        _no_error -> changeset
      end
    end

    validate_count = fn changeset ->
      count = changeset |> apply_changes() |> set_count()

      cond do
        count == 0 ->
          add_error(changeset, :dates, "pick at least one date")

        count > @max_sets ->
          add_error(changeset, :dates, "would create more than #{@max_sets} sets")

        true ->
          changeset
      end
    end

    schedule
    |> cast(attrs, [:copies, :per_side, :dates, :range_from, :range_to])
    |> validate_required([:copies, :per_side])
    |> validate_number(:copies, greater_than: 0, less_than_or_equal_to: @max_copies)
    |> validate_range.()
    |> validate_count.()
  end

  @spec new(map()) :: {:ok, t()} | {:error, Ecto.Changeset.t()}
  def new(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
    |> apply_action(:insert)
  end

  @doc "Every scheduled date, ascending and without duplicates."
  @spec dates(t()) :: [Date.t()]
  def dates(%__MODULE__{dates: dates} = schedule) do
    range = fn
      %__MODULE__{range_from: %Date{} = from, range_to: %Date{} = to} ->
        Enum.to_list(Date.range(from, to, 1))

      %__MODULE__{} ->
        []
    end

    (dates ++ range.(schedule))
    |> Enum.uniq()
    |> Enum.sort(Date)
  end

  @doc """
  Copies the template once per date × copy × side. A per-side schedule
  alternates left and right within each copy; otherwise the template's own
  side is kept.
  """
  @spec expand(t(), PlannedSet.t()) :: [PlannedSet.t()]
  def expand(%__MODULE__{} = schedule, %PlannedSet{} = template) do
    for date <- dates(schedule), _copy <- 1..schedule.copies, side <- sides(schedule, template) do
      %{template | planned_on: date, side: side}
    end
  end

  @doc "How many planned sets the schedule creates."
  @spec set_count(t()) :: non_neg_integer()
  def set_count(%__MODULE__{} = schedule) do
    length(dates(schedule)) * schedule.copies * length(sides(schedule, %PlannedSet{}))
  end

  defp sides(%__MODULE__{per_side: true}, _template), do: SetMetrics.sides()
  defp sides(%__MODULE__{per_side: false}, %PlannedSet{side: side}), do: [side]
end
