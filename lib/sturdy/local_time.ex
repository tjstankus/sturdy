defmodule Sturdy.LocalTime do
  @moduledoc """
  Conversions between stored UTC timestamps and the app's single configured
  timezone (`config :sturdy, :timezone`). A timestamp's day is its local date.
  """

  @type timezone :: String.t()

  @spec timezone() :: timezone()
  def timezone, do: Application.fetch_env!(:sturdy, :timezone)

  @doc "Today's local date."
  @spec today() :: Date.t()
  def today, do: date_of(DateTime.utc_now())

  @doc "The local date of a UTC timestamp."
  @spec date_of(DateTime.t()) :: Date.t()
  def date_of(%DateTime{} = datetime), do: datetime |> to_local() |> DateTime.to_date()

  @doc "A UTC timestamp shifted into the app timezone."
  @spec to_local(DateTime.t()) :: DateTime.t()
  def to_local(%DateTime{} = datetime), do: DateTime.shift_zone!(datetime, timezone())

  @doc """
  The UTC instant of a local wall-clock time. Ambiguous times (DST fall-back)
  resolve to the earlier instant; times in a DST gap resolve to just after it.
  """
  @spec from_local(NaiveDateTime.t()) :: DateTime.t()
  def from_local(%NaiveDateTime{} = naive) do
    resolve = fn
      {:ok, datetime} -> datetime
      {:ambiguous, earlier, _later} -> earlier
      {:gap, _before, just_after} -> just_after
    end

    naive
    |> DateTime.from_naive(timezone())
    |> resolve.()
    |> DateTime.shift_zone!("Etc/UTC")
  end

  @doc "The UTC half-open interval `[start, next_start)` covering a local date."
  @spec day_bounds(Date.t()) :: {DateTime.t(), DateTime.t()}
  def day_bounds(%Date{} = date) do
    midnight = fn day -> day |> NaiveDateTime.new!(~T[00:00:00]) |> from_local() end
    {midnight.(date), midnight.(Date.add(date, 1))}
  end
end
