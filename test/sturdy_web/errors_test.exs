defmodule SturdyWeb.ErrorsTest do
  use ExUnit.Case, async: true

  alias SturdyWeb.Errors

  test "summary/1 humanizes fields and joins messages" do
    changeset =
      {%{}, %{movement_id: :integer, reps: :integer}}
      |> Ecto.Changeset.change()
      |> Ecto.Changeset.add_error(:movement_id, "can't be blank")
      |> Ecto.Changeset.add_error(:reps, "must be greater than %{number}", number: 0)

    assert Errors.summary(changeset) == "Movement can't be blank; Reps must be greater than 0"
  end
end
