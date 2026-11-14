defmodule Sturdy.Catalog.Tag do
  @moduledoc """
  A label attached to movements. Muscles are tags too; the category says which
  kind of label a tag is. Names are unique within a category.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Sturdy.Catalog.TagCategory
  alias Sturdy.Changesets

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          tag_category_id: integer() | nil,
          tag_category: TagCategory.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "tags" do
    field :name, :string

    belongs_to :tag_category, TagCategory

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:name, :tag_category_id])
    |> Changesets.trim(:name)
    |> validate_required([:name, :tag_category_id])
    |> validate_length(:name, max: 60)
    |> assoc_constraint(:tag_category)
    |> unique_constraint(:name,
      name: :tags_tag_category_id_name_index,
      message: "already exists in this category"
    )
  end
end
