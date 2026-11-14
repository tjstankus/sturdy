defmodule Sturdy.Catalog.Movement do
  @moduledoc """
  Something performed in sets. Each variation is its own movement
  ("Paused Bench Press" is distinct from "Bench Press").

  `tag_ids` is a virtual field: the changeset casts it, and the `Sturdy.Catalog`
  context resolves the ids into tags. Absent `tag_ids` means "leave tags alone";
  an empty list means "remove all tags".
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Sturdy.Catalog.MovementVideo
  alias Sturdy.Catalog.Tag
  alias Sturdy.Changesets

  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          notes: String.t() | nil,
          tag_ids: [integer()] | nil,
          videos: [MovementVideo.t()] | Ecto.Association.NotLoaded.t(),
          tags: [Tag.t()] | Ecto.Association.NotLoaded.t(),
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "movements" do
    field :name, :string
    field :notes, :string
    field :tag_ids, {:array, :integer}, virtual: true

    has_many :videos, MovementVideo, on_replace: :delete, preload_order: [asc: :id]

    many_to_many :tags, Tag,
      join_through: "movement_tags",
      on_replace: :delete,
      preload_order: [asc: :name]

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(movement, attrs) do
    movement
    |> cast(attrs, [:name, :notes, :tag_ids])
    |> Changesets.trim(:name)
    |> validate_required([:name])
    |> validate_length(:name, max: 100)
    |> unique_constraint(:name, name: :movements_name_index)
    |> cast_assoc(:videos,
      with: &MovementVideo.changeset/2,
      sort_param: :videos_sort,
      drop_param: :videos_drop
    )
  end

  @doc """
  Replaces the movement's tags with the given, already-loaded tags.
  """
  @spec put_tags(Ecto.Changeset.t(), [Tag.t()]) :: Ecto.Changeset.t()
  def put_tags(changeset, tags), do: put_assoc(changeset, :tags, tags)
end
