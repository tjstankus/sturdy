defmodule Sturdy.CatalogFixtures do
  @moduledoc """
  Test helpers for creating catalog records.
  """

  alias Sturdy.Catalog
  alias Sturdy.Catalog.Movement
  alias Sturdy.Catalog.Tag
  alias Sturdy.Catalog.TagCategory

  @spec unique_name(String.t()) :: String.t()
  def unique_name(prefix), do: "#{prefix} #{System.unique_integer([:positive])}"

  @spec tag_category_fixture(map()) :: TagCategory.t()
  def tag_category_fixture(attrs \\ %{}) do
    {:ok, category} =
      attrs
      |> Enum.into(%{name: unique_name("category")})
      |> Catalog.create_tag_category()

    category
  end

  @spec tag_fixture(map()) :: Tag.t()
  def tag_fixture(attrs \\ %{}) do
    {:ok, tag} =
      attrs
      |> Enum.into(%{name: unique_name("tag")})
      |> Map.put_new_lazy(:tag_category_id, fn -> tag_category_fixture().id end)
      |> Catalog.create_tag()

    tag
  end

  @spec movement_fixture(map()) :: Movement.t()
  def movement_fixture(attrs \\ %{}) do
    {:ok, movement} =
      attrs
      |> Enum.into(%{name: unique_name("movement")})
      |> Catalog.create_movement()

    movement
  end
end
