defmodule SturdyWeb.SetFormat do
  @moduledoc """
  Human-readable set measurements, e.g. "5 reps · 100 lb · L".
  Units are fixed: pounds, meters, seconds.
  """

  alias Sturdy.Training.CompletedSet
  alias Sturdy.Training.PlannedSet

  @doc "Every present measurement of a set, joined with middots."
  @spec summary(PlannedSet.t() | CompletedSet.t()) :: String.t()
  def summary(set) do
    [
      reps(set.reps),
      duration(set.duration_s),
      distance(set.distance_m),
      weight(set.weight_lb),
      side(set.side)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" · ")
  end

  @spec reps(pos_integer() | nil) :: String.t() | nil
  def reps(nil), do: nil
  def reps(1), do: "1 rep"
  def reps(reps), do: "#{reps} reps"

  @doc "Seconds as `45s`, or `m:ss` from a minute up."
  @spec duration(pos_integer() | nil) :: String.t() | nil
  def duration(nil), do: nil
  def duration(seconds) when seconds < 60, do: "#{seconds}s"

  def duration(seconds) do
    "#{div(seconds, 60)}:#{seconds |> rem(60) |> Integer.to_string() |> String.pad_leading(2, "0")}"
  end

  @spec distance(pos_integer() | nil) :: String.t() | nil
  def distance(nil), do: nil
  def distance(meters), do: "#{meters} m"

  @doc "External load: `BW` for bodyweight (0), `−40 lb` for assistance."
  @spec weight(Decimal.t() | nil) :: String.t() | nil
  def weight(nil), do: nil

  def weight(%Decimal{} = pounds) do
    text = fn amount ->
      amount |> Decimal.abs() |> Decimal.normalize() |> Decimal.to_string(:normal)
    end

    case Decimal.compare(pounds, 0) do
      :eq -> "BW"
      :gt -> "#{text.(pounds)} lb"
      :lt -> "−#{text.(pounds)} lb"
    end
  end

  @spec side(:left | :right | nil) :: String.t() | nil
  def side(nil), do: nil
  def side(:left), do: "L"
  def side(:right), do: "R"
end
