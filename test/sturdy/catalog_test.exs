defmodule Sturdy.CatalogTest do
  use Sturdy.DataCase, async: true

  import Sturdy.CatalogFixtures

  alias Sturdy.Catalog
  alias Sturdy.Catalog.Movement

  describe "tag categories" do
    test "create, update, list with tags alphabetically" do
      {:ok, modality} = Catalog.create_tag_category(%{name: "modality"})
      {:ok, muscle} = Catalog.create_tag_category(%{name: "Muscle"})
      tag_fixture(%{name: "triceps", tag_category_id: muscle.id})
      tag_fixture(%{name: "pecs", tag_category_id: muscle.id})

      assert [%{name: "modality", tags: []}, %{name: "Muscle", tags: tags}] =
               Catalog.list_tag_categories()

      assert Enum.map(tags, & &1.name) == ["pecs", "triceps"]

      assert {:ok, %{name: "modalities"}} =
               Catalog.update_tag_category(modality, %{name: "modalities"})
    end

    test "names are unique regardless of case" do
      tag_category_fixture(%{name: "muscle"})

      assert {:error, changeset} = Catalog.create_tag_category(%{name: "MUSCLE"})
      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end

    test "a category with tags cannot be deleted" do
      category = tag_category_fixture()
      tag_fixture(%{tag_category_id: category.id})

      assert {:error, changeset} = Catalog.delete_tag_category(category)
      assert %{tags: ["still has tags"]} = errors_on(changeset)
    end

    test "an empty category can be deleted" do
      category = tag_category_fixture()
      assert {:ok, _} = Catalog.delete_tag_category(category)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_tag_category!(category.id) end
    end

    test "change_tag_category/2 returns a changeset" do
      assert %Ecto.Changeset{} = Catalog.change_tag_category(tag_category_fixture())
    end
  end

  describe "tags" do
    test "a name is unique within its category, not across categories" do
      muscle = tag_category_fixture()
      other = tag_category_fixture()
      tag_fixture(%{name: "core", tag_category_id: muscle.id})

      assert {:error, changeset} =
               Catalog.create_tag(%{name: "Core", tag_category_id: muscle.id})

      assert %{name: ["already exists in this category"]} = errors_on(changeset)
      assert {:ok, _} = Catalog.create_tag(%{name: "core", tag_category_id: other.id})
    end

    test "requires an existing category" do
      assert {:error, changeset} = Catalog.create_tag(%{name: "x", tag_category_id: -1})
      assert %{tag_category: ["does not exist"]} = errors_on(changeset)
    end

    test "update, get, delete" do
      tag = tag_fixture()
      assert {:ok, %{name: "glutes"}} = Catalog.update_tag(tag, %{name: "glutes"})
      assert Catalog.get_tag!(tag.id).name == "glutes"
      assert {:ok, _} = Catalog.delete_tag(tag)
      assert %Ecto.Changeset{} = Catalog.change_tag(tag)
    end

    test "deleting a tag removes it from movements" do
      tag = tag_fixture()
      movement = movement_fixture(%{tag_ids: [tag.id]})

      {:ok, _} = Catalog.delete_tag(tag)

      assert Catalog.get_movement!(movement.id).tags == []
    end
  end

  describe "movements" do
    test "create with tags and videos" do
      pecs = tag_fixture(%{name: "pecs"})
      iso = tag_fixture(%{name: "isometric"})

      assert {:ok, movement} =
               Catalog.create_movement(%{
                 name: "Paused Bench Press",
                 notes: "two-count pause",
                 tag_ids: [pecs.id, iso.id],
                 videos: %{
                   "0" => %{url: "https://youtu.be/abc?t=30", label: "setup"},
                   "1" => %{url: "https://youtu.be/def"}
                 }
               })

      movement = Catalog.get_movement!(movement.id)
      assert Enum.map(movement.tags, & &1.name) == ["isometric", "pecs"]
      assert Enum.map(movement.videos, & &1.label) == ["setup", nil]
      assert %{tag_category: %{}} = hd(movement.tags)
    end

    test "names are unique regardless of case" do
      movement_fixture(%{name: "Bench Press"})
      assert {:error, changeset} = Catalog.create_movement(%{name: "bench press"})
      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end

    test "update replaces tags when tag_ids is given and keeps them when absent" do
      a = tag_fixture()
      b = tag_fixture()
      movement = movement_fixture(%{tag_ids: [a.id]}) |> reload()

      {:ok, movement} = Catalog.update_movement(movement, %{notes: "new cue"})
      assert [%{id: a_id}] = reload(movement).tags
      assert a_id == a.id

      {:ok, movement} = Catalog.update_movement(reload(movement), %{tag_ids: [b.id]})
      assert [%{id: b_id}] = reload(movement).tags
      assert b_id == b.id

      {:ok, movement} = Catalog.update_movement(reload(movement), %{tag_ids: [""]})
      assert reload(movement).tags == []
    end

    test "update can drop a video" do
      movement =
        movement_fixture(%{
          videos: %{"0" => %{url: "https://a.com/1"}, "1" => %{url: "https://a.com/2"}}
        })
        |> reload()

      [first, second] = movement.videos

      {:ok, movement} =
        Catalog.update_movement(movement, %{
          videos: %{
            "0" => %{id: first.id, url: first.url},
            "1" => %{id: second.id, url: second.url}
          },
          videos_drop: ["1"]
        })

      assert Enum.map(reload(movement).videos, & &1.id) == [first.id]
    end

    test "list_movements/1 sorts by name and filters by tag" do
      tag = tag_fixture()
      movement_fixture(%{name: "squat"})
      movement_fixture(%{name: "Bench", tag_ids: [tag.id]})

      assert ["Bench", "squat"] = Enum.map(Catalog.list_movements(), & &1.name)
      assert [%Movement{name: "Bench"}] = Catalog.list_movements(tag_id: tag.id)
    end

    test "delete removes the movement and its videos" do
      movement = movement_fixture(%{videos: %{"0" => %{url: "https://a.com/1"}}})
      assert {:ok, _} = Catalog.delete_movement(movement)
      assert_raise Ecto.NoResultsError, fn -> Catalog.get_movement!(movement.id) end
      assert Repo.aggregate(Sturdy.Catalog.MovementVideo, :count) == 0
    end

    test "change_movement/2 returns a changeset" do
      assert %Ecto.Changeset{} = Catalog.change_movement(%Movement{videos: []})
    end
  end

  defp reload(movement), do: Catalog.get_movement!(movement.id)
end
