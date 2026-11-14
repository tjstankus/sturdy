defmodule Sturdy.Body do
  @moduledoc """
  The bodyweight log.
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Sturdy.Body.BodyweightEntry
  alias Sturdy.Repo

  @type result(t) :: {:ok, t} | {:error, Changeset.t()}

  @doc "All entries, most recent first."
  @spec list_bodyweight_entries() :: [BodyweightEntry.t()]
  def list_bodyweight_entries do
    BodyweightEntry
    |> order_by(desc: :measured_on)
    |> Repo.all()
  end

  @doc "The most recent entry on or before `date`, if any."
  @spec bodyweight_on(Date.t()) :: BodyweightEntry.t() | nil
  def bodyweight_on(%Date{} = date) do
    BodyweightEntry
    |> where([e], e.measured_on <= ^date)
    |> order_by(desc: :measured_on)
    |> limit(1)
    |> Repo.one()
  end

  @spec get_bodyweight_entry!(integer() | String.t()) :: BodyweightEntry.t()
  def get_bodyweight_entry!(id), do: Repo.get!(BodyweightEntry, id)

  @spec create_bodyweight_entry(map()) :: result(BodyweightEntry.t())
  def create_bodyweight_entry(attrs) do
    %BodyweightEntry{}
    |> BodyweightEntry.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_bodyweight_entry(BodyweightEntry.t(), map()) :: result(BodyweightEntry.t())
  def update_bodyweight_entry(%BodyweightEntry{} = entry, attrs) do
    entry
    |> BodyweightEntry.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_bodyweight_entry(BodyweightEntry.t()) :: result(BodyweightEntry.t())
  def delete_bodyweight_entry(%BodyweightEntry{} = entry), do: Repo.delete(entry)

  @spec change_bodyweight_entry(BodyweightEntry.t(), map()) :: Changeset.t()
  def change_bodyweight_entry(%BodyweightEntry{} = entry, attrs \\ %{}) do
    BodyweightEntry.changeset(entry, attrs)
  end
end
