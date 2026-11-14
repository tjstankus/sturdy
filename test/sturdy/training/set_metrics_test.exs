defmodule Sturdy.Training.SetMetricsTest do
  use ExUnit.Case, async: true

  import Sturdy.DataCase, only: [errors_on: 1]

  alias Sturdy.Training.SetMetrics

  @types %{
    side: {:parameterized, {Ecto.Enum, Ecto.Enum.init(values: [:left, :right])}},
    reps: :integer,
    duration_s: :integer,
    distance_m: :integer,
    weight_lb: :decimal,
    notes: :string
  }

  defp validate(params) do
    {%{}, @types}
    |> Ecto.Changeset.cast(params, Map.keys(@types))
    |> SetMetrics.validate()
  end

  test "any one of reps, duration, or distance is enough" do
    assert validate(%{reps: 5}).valid?
    assert validate(%{duration_s: 30}).valid?
    assert validate(%{distance_m: 40, weight_lb: 50}).valid?
  end

  test "weight alone is not a set" do
    assert %{reps: ["enter reps, duration, or distance"]} = errors_on(validate(%{weight_lb: 100}))
  end

  test "measures must be positive" do
    errors = errors_on(validate(%{reps: 0, duration_s: -1, distance_m: 0}))
    assert errors.reps == ["must be greater than 0"]
    assert errors.duration_s == ["must be greater than 0"]
    assert errors.distance_m == ["must be greater than 0"]
  end

  test "weight may be negative (assistance) or zero (bodyweight)" do
    assert validate(%{reps: 8, weight_lb: -40}).valid?
    assert validate(%{reps: 8, weight_lb: 0}).valid?
  end

  test "fields/0 and sides/0" do
    assert :weight_lb in SetMetrics.fields()
    assert SetMetrics.sides() == [:left, :right]
  end
end
