defmodule Sturdy.ChangesetsTest do
  use ExUnit.Case, async: true

  alias Sturdy.Changesets

  defp changeset(data, params) do
    Ecto.Changeset.cast({data, %{name: :string}}, params, [:name])
  end

  test "trims a string change" do
    assert %{name: "Bench"} =
             %{} |> changeset(%{name: "  Bench "}) |> Changesets.trim(:name) |> Map.get(:changes)
  end

  test "leaves a nil change alone" do
    changeset = %{name: "Bench"} |> changeset(%{name: nil}) |> Changesets.trim(:name)
    assert changeset.changes == %{name: nil}
  end
end
