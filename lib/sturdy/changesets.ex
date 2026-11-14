defmodule Sturdy.Changesets do
  @moduledoc """
  Small changeset transformations shared across schemas.
  """

  import Ecto.Changeset, only: [update_change: 3]

  @doc """
  Trims surrounding whitespace from a string change, leaving other values alone.
  """
  @spec trim(Ecto.Changeset.t(), atom()) :: Ecto.Changeset.t()
  def trim(changeset, field) do
    update_change(changeset, field, fn
      value when is_binary(value) -> String.trim(value)
      value -> value
    end)
  end
end
