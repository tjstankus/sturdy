defmodule SturdyWeb.DateParam do
  @moduledoc """
  Reads the `"date"` route param (ISO 8601), defaulting to today's local date.
  """

  alias Sturdy.LocalTime

  @spec fetch(map()) :: {:ok, Date.t()} | :error
  def fetch(%{"date" => iso}) do
    case Date.from_iso8601(iso) do
      {:ok, date} -> {:ok, date}
      {:error, _reason} -> :error
    end
  end

  def fetch(_params), do: {:ok, LocalTime.today()}

  @doc "A short label: `Today`, `Yesterday`, `Tomorrow`, else e.g. `Sat, Nov 14`."
  @spec label(Date.t()) :: String.t()
  def label(%Date{} = date) do
    relative = %{0 => "Today", -1 => "Yesterday", 1 => "Tomorrow"}

    Map.get_lazy(relative, Date.diff(date, LocalTime.today()), fn ->
      Calendar.strftime(date, "%a, %b %-d")
    end)
  end
end
