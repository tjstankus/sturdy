defmodule SturdyWeb.LocalDateTimeInput do
  @moduledoc """
  Bridges `<input type="datetime-local">` (local wall-clock time, minute
  precision) and the UTC timestamps the domain stores.
  """

  alias Sturdy.LocalTime

  @doc """
  The input's value for a field. A `DateTime` is shown in local time; a string
  is a value the user already typed and is shown as-is.
  """
  @spec to_input(DateTime.t() | String.t() | nil) :: String.t()
  def to_input(%DateTime{} = datetime),
    do: datetime |> LocalTime.to_local() |> Calendar.strftime("%Y-%m-%dT%H:%M")

  def to_input(value) when is_binary(value), do: value
  def to_input(nil), do: ""

  @doc "Parses an input value (`YYYY-MM-DDTHH:MM`, seconds optional) as local time."
  @spec to_utc(String.t()) :: {:ok, DateTime.t()} | :error
  def to_utc(local) when is_binary(local) do
    with_seconds = fn
      <<_date::binary-size(10), "T", _hh_mm::binary-size(5)>> = minute -> minute <> ":00"
      other -> other
    end

    case local |> with_seconds.() |> NaiveDateTime.from_iso8601() do
      {:ok, naive} -> {:ok, LocalTime.from_local(naive)}
      {:error, _reason} -> :error
    end
  end

  @doc """
  Replaces a local input value in form params with its UTC instant. Unparseable
  values are left for the changeset to reject.
  """
  @spec put_utc(map(), String.t()) :: map()
  def put_utc(params, key) do
    with %{^key => local} when is_binary(local) <- params,
         {:ok, utc} <- to_utc(local) do
      Map.put(params, key, utc)
    else
      _unchanged -> params
    end
  end
end
