defimpl Phoenix.Param, for: Date do
  @moduledoc """
  Dates appear in routes as ISO 8601, e.g. `~p"/days/\#{date}"` → `/days/2026-11-14`.
  """

  @spec to_param(Date.t()) :: String.t()
  def to_param(date), do: Date.to_iso8601(date)
end
