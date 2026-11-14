defmodule Sturdy.Catalog.TagCategory do
  @moduledoc """
  A user-defined grouping of tags, e.g. "muscle" or "modality".
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Sturdy.Catalog.Tag
  alias Sturdy.Changesets

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          tags: [Tag.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "tag_categories" do
    field :name, :string

    has_many :tags, Tag, preload_order: [asc: :name]

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(category, attrs) do
    category
    |> cast(attrs, [:name])
    |> Changesets.trim(:name)
    |> validate_required([:name])
    |> validate_length(:name, max: 60)
    |> unique_constraint(:name, name: :tag_categories_name_index)
  end

  @doc """
  A category cannot be deleted while it still has tags.
  """
  @spec delete_changeset(t()) :: Ecto.Changeset.t()
  def delete_changeset(category) do
    category
    |> change()
    |> no_assoc_constraint(:tags, message: "still has tags")
  end
end
