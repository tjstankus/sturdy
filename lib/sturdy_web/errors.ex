defmodule SturdyWeb.Errors do
  @moduledoc """
  One-line summaries of changeset errors for flash messages,
  e.g. "Movement has planned sets".
  """

  @doc """
  The changeset's own (not nested) errors, in the order they were added.
  """
  @spec summary(Ecto.Changeset.t()) :: String.t()
  def summary(%Ecto.Changeset{errors: errors}) do
    errors
    |> Enum.reverse()
    |> Enum.map_join("; ", fn {field, error} ->
      "#{Phoenix.Naming.humanize(field)} #{SturdyWeb.CoreComponents.translate_error(error)}"
    end)
  end
end
