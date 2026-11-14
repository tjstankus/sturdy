defmodule Sturdy.Training.SetMetrics do
  @moduledoc """
  The measurements shared by planned and completed sets. Units are fixed by
  design: pounds, meters, seconds.

  * `side` — `:left` / `:right` for unilateral work, `nil` for bilateral
  * `weight_lb` — external load: 0 is bodyweight, negative is assistance

  A set needs at least one of reps, duration, or distance.
  """

  import Ecto.Changeset

  @type side :: :left | :right | nil

  @sides [:left, :right]
  @measures [:reps, :duration_s, :distance_m]
  @fields [:side | @measures] ++ [:weight_lb, :notes]

  @doc "Declares the metric fields inside an `Ecto.Schema` `schema` block."
  defmacro schema_fields do
    quote do
      field :side, Ecto.Enum, values: unquote(@sides)
      field :reps, :integer
      field :duration_s, :integer
      field :distance_m, :integer
      field :weight_lb, :decimal
      field :notes, :string
    end
  end

  @spec fields() :: [atom()]
  def fields, do: @fields

  @spec sides() :: [:left | :right]
  def sides, do: @sides

  @spec validate(Ecto.Changeset.t()) :: Ecto.Changeset.t()
  def validate(changeset) do
    require_measure = fn changeset ->
      if Enum.any?(@measures, &get_field(changeset, &1)) do
        changeset
      else
        add_error(changeset, :reps, "enter reps, duration, or distance")
      end
    end

    changeset
    |> validate_number(:reps, greater_than: 0)
    |> validate_number(:duration_s, greater_than: 0)
    |> validate_number(:distance_m, greater_than: 0)
    |> validate_number(:weight_lb, greater_than: -10_000, less_than: 10_000)
    |> require_measure.()
  end
end
