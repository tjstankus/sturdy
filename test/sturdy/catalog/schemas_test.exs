defmodule Sturdy.Catalog.SchemasTest do
  use ExUnit.Case, async: true

  import Sturdy.DataCase, only: [errors_on: 1]

  alias Sturdy.Catalog.Movement
  alias Sturdy.Catalog.MovementVideo
  alias Sturdy.Catalog.Tag
  alias Sturdy.Catalog.TagCategory

  describe "TagCategory.changeset/2" do
    test "requires a name" do
      assert %{name: ["can't be blank"]} =
               errors_on(TagCategory.changeset(%TagCategory{}, %{name: "   "}))
    end

    test "trims the name" do
      changeset = TagCategory.changeset(%TagCategory{}, %{name: " muscle "})
      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :name) == "muscle"
    end
  end

  describe "Tag.changeset/2" do
    test "requires a name and a category" do
      errors = errors_on(Tag.changeset(%Tag{}, %{}))
      assert errors.name == ["can't be blank"]
      assert errors.tag_category_id == ["can't be blank"]
    end
  end

  describe "MovementVideo.changeset/2" do
    test "accepts an https URL with an optional label" do
      assert MovementVideo.changeset(%MovementVideo{}, %{url: "https://youtu.be/x?t=42"}).valid?

      assert MovementVideo.changeset(%MovementVideo{}, %{url: "http://x.com/v", label: "cues"}).valid?
    end

    for url <- ["not a url", "ftp://x.com/v", "https://", "/relative"] do
      test "rejects #{inspect(url)}" do
        assert %{url: ["must be an http or https URL"]} =
                 errors_on(MovementVideo.changeset(%MovementVideo{}, %{url: unquote(url)}))
      end
    end

    test "requires a URL" do
      assert %{url: ["can't be blank"]} =
               errors_on(MovementVideo.changeset(%MovementVideo{}, %{}))
    end
  end

  describe "Movement.changeset/2" do
    test "requires a name" do
      assert %{name: ["can't be blank"]} =
               errors_on(Movement.changeset(%Movement{videos: []}, %{name: ""}))
    end

    test "casts tag ids, dropping blanks from form submissions" do
      changeset = Movement.changeset(%Movement{videos: []}, %{name: "Plank", tag_ids: ["", "3"]})
      assert Ecto.Changeset.get_change(changeset, :tag_ids) == [3]
    end

    test "casts nested videos and validates them" do
      changeset =
        Movement.changeset(%Movement{videos: []}, %{
          name: "Plank",
          videos: %{"0" => %{url: "nope"}}
        })

      assert %{videos: [%{url: ["must be an http or https URL"]}]} = errors_on(changeset)
    end
  end
end
