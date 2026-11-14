defmodule Sturdy.Catalog do
  @moduledoc """
  Movements and the tags and videos that describe them.
  """

  import Ecto.Query

  alias Ecto.Changeset
  alias Sturdy.Catalog.Movement
  alias Sturdy.Catalog.Tag
  alias Sturdy.Catalog.TagCategory
  alias Sturdy.Repo

  @type result(t) :: {:ok, t} | {:error, Changeset.t()}

  # Tag categories

  @doc """
  All categories, alphabetically, each with its tags preloaded.
  """
  @spec list_tag_categories() :: [TagCategory.t()]
  def list_tag_categories do
    TagCategory
    |> order_by([c], fragment("lower(?)", c.name))
    |> preload(:tags)
    |> Repo.all()
  end

  @spec get_tag_category!(integer() | String.t()) :: TagCategory.t()
  def get_tag_category!(id), do: Repo.get!(TagCategory, id)

  @spec create_tag_category(map()) :: result(TagCategory.t())
  def create_tag_category(attrs) do
    %TagCategory{}
    |> TagCategory.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_tag_category(TagCategory.t(), map()) :: result(TagCategory.t())
  def update_tag_category(%TagCategory{} = category, attrs) do
    category
    |> TagCategory.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_tag_category(TagCategory.t()) :: result(TagCategory.t())
  def delete_tag_category(%TagCategory{} = category) do
    category
    |> TagCategory.delete_changeset()
    |> Repo.delete()
  end

  @spec change_tag_category(TagCategory.t(), map()) :: Changeset.t()
  def change_tag_category(%TagCategory{} = category, attrs \\ %{}) do
    TagCategory.changeset(category, attrs)
  end

  # Tags

  @spec get_tag!(integer() | String.t()) :: Tag.t()
  def get_tag!(id), do: Repo.get!(Tag, id)

  @spec create_tag(map()) :: result(Tag.t())
  def create_tag(attrs) do
    %Tag{}
    |> Tag.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_tag(Tag.t(), map()) :: result(Tag.t())
  def update_tag(%Tag{} = tag, attrs) do
    tag
    |> Tag.changeset(attrs)
    |> Repo.update()
  end

  @spec delete_tag(Tag.t()) :: result(Tag.t())
  def delete_tag(%Tag{} = tag), do: Repo.delete(tag)

  @spec change_tag(Tag.t(), map()) :: Changeset.t()
  def change_tag(%Tag{} = tag, attrs \\ %{}), do: Tag.changeset(tag, attrs)

  # Movements

  @doc """
  Movements alphabetically, with tags preloaded.

  Options:
    * `:tag_id` — only movements carrying this tag
  """
  @spec list_movements(keyword()) :: [Movement.t()]
  def list_movements(opts \\ []) do
    by_tag = fn
      query, nil -> query
      query, tag_id -> from m in query, join: t in assoc(m, :tags), where: t.id == ^tag_id
    end

    Movement
    |> by_tag.(Keyword.get(opts, :tag_id))
    |> order_by([m], fragment("lower(?)", m.name))
    |> preload(:tags)
    |> Repo.all()
  end

  @doc """
  A movement with its videos and tags (with categories) preloaded.
  """
  @spec get_movement!(integer() | String.t()) :: Movement.t()
  def get_movement!(id) do
    Movement
    |> Repo.get!(id)
    |> Repo.preload([:videos, tags: :tag_category])
  end

  @spec create_movement(map()) :: result(Movement.t())
  def create_movement(attrs) do
    %Movement{videos: [], tags: []}
    |> Movement.changeset(attrs)
    |> resolve_tags()
    |> Repo.insert()
  end

  @doc """
  Updates a movement. The movement must have `:videos` and `:tags` preloaded
  (as `get_movement!/1` returns it).
  """
  @spec update_movement(Movement.t(), map()) :: result(Movement.t())
  def update_movement(%Movement{} = movement, attrs) do
    movement
    |> Movement.changeset(attrs)
    |> resolve_tags()
    |> Repo.update()
  end

  @doc """
  Deletes a movement. Training records reference movements with a restricting
  foreign key, so a movement with any planned or completed sets cannot be deleted.
  """
  @spec delete_movement(Movement.t()) :: result(Movement.t())
  def delete_movement(%Movement{} = movement) do
    movement
    |> Changeset.change()
    |> Changeset.foreign_key_constraint(:id,
      name: :planned_sets_movement_id_fkey,
      message: "has planned sets"
    )
    |> Changeset.foreign_key_constraint(:id,
      name: :completed_sets_movement_id_fkey,
      message: "has completed sets"
    )
    |> Repo.delete()
  end

  @spec change_movement(Movement.t(), map()) :: Changeset.t()
  def change_movement(%Movement{} = movement, attrs \\ %{}) do
    Movement.changeset(movement, attrs)
  end

  # Turns the virtual `tag_ids` change into loaded tags. Used by create and update.
  defp resolve_tags(%Changeset{changes: %{tag_ids: ids}} = changeset) do
    Movement.put_tags(changeset, Repo.all(from t in Tag, where: t.id in ^ids))
  end

  defp resolve_tags(changeset), do: changeset
end
