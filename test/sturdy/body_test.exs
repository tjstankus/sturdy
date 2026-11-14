defmodule Sturdy.BodyTest do
  use Sturdy.DataCase, async: true

  alias Sturdy.Body
  alias Sturdy.Body.BodyweightEntry

  defp entry!(date, lb) do
    {:ok, entry} = Body.create_bodyweight_entry(%{measured_on: date, weight_lb: lb})
    entry
  end

  test "entries list most recent first" do
    entry!(~D[2026-11-01], 180)
    entry!(~D[2026-11-08], "178.5")

    assert [%{measured_on: ~D[2026-11-08]}, %{measured_on: ~D[2026-11-01]}] =
             Body.list_bodyweight_entries()
  end

  test "one entry per day" do
    entry!(~D[2026-11-01], 180)

    assert {:error, changeset} =
             Body.create_bodyweight_entry(%{measured_on: ~D[2026-11-01], weight_lb: 181})

    assert %{measured_on: ["already has an entry"]} = errors_on(changeset)
  end

  test "weight is required and positive" do
    assert {:error, changeset} =
             Body.create_bodyweight_entry(%{measured_on: ~D[2026-11-01], weight_lb: 0})

    assert %{weight_lb: [_]} = errors_on(changeset)
  end

  test "bodyweight_on/1 is the latest entry on or before the date" do
    entry!(~D[2026-11-01], 180)
    entry!(~D[2026-11-08], 178)

    assert Body.bodyweight_on(~D[2026-10-31]) == nil
    assert Decimal.equal?(Body.bodyweight_on(~D[2026-11-05]).weight_lb, 180)
    assert Decimal.equal?(Body.bodyweight_on(~D[2026-11-08]).weight_lb, 178)
  end

  test "get, update, delete, change" do
    entry = entry!(~D[2026-11-01], 180)
    assert Body.get_bodyweight_entry!(entry.id).id == entry.id
    assert {:ok, updated} = Body.update_bodyweight_entry(entry, %{weight_lb: 179})
    assert Decimal.equal?(updated.weight_lb, 179)
    assert {:ok, _} = Body.delete_bodyweight_entry(updated)
    assert %Ecto.Changeset{} = Body.change_bodyweight_entry(%BodyweightEntry{})
  end
end
