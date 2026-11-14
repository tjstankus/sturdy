defmodule SturdyWeb.MovementLiveTest do
  use SturdyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Sturdy.CatalogFixtures
  import Sturdy.TrainingFixtures

  alias Sturdy.Catalog

  describe "index" do
    test "lists movements and filters by tag", %{conn: conn} do
      pecs = tag_fixture(%{name: "pecs"})
      bench = movement_fixture(%{name: "Bench", tag_ids: [pecs.id]})
      squat = movement_fixture(%{name: "Squat"})

      {:ok, view, _html} = live(conn, ~p"/movements")
      assert has_element?(view, "#movements-#{bench.id}", "pecs")
      assert has_element?(view, "#movements-#{squat.id}")

      view |> element("#filter-tag-#{pecs.id}") |> render_click()
      assert_patch(view, ~p"/movements?tag=#{pecs.id}")
      refute has_element?(view, "#movements-#{squat.id}")

      view |> element("#filter-all") |> render_click()
      assert has_element?(view, "#movements-#{squat.id}")
    end

    test "an unusable tag filter shows everything", %{conn: conn} do
      movement = movement_fixture()
      {:ok, view, _html} = live(conn, ~p"/movements?tag=abc")
      assert has_element?(view, "#movements-#{movement.id}")
    end
  end

  describe "form" do
    test "creates a movement with tags and a video", %{conn: conn} do
      iso = tag_fixture(%{name: "isometric"})
      {:ok, view, _html} = live(conn, ~p"/movements/new")

      # The add/remove buttons dispatch a form change carrying these params.
      assert has_element?(view, "#add-video")
      add_video = %{"movement" => %{"name" => "Plank", "videos_sort" => ["new"]}}
      render_change(view, "validate", add_video)
      assert has_element?(view, "#remove-video-0")

      remove_video = %{
        "videos_sort" => ["0"],
        "videos_drop" => ["0"],
        "videos" => %{"0" => %{"url" => ""}}
      }

      render_change(view, "validate", %{
        "movement" => Map.merge(%{"name" => "Plank"}, remove_video)
      })

      refute has_element?(view, "#video-0")
      render_change(view, "validate", add_video)

      assert view |> form("#movement-form", %{"movement" => %{"name" => ""}}) |> render_change() =~
               "can&#39;t be blank"

      params = %{
        "movement" => %{
          "name" => "Plank",
          "notes" => "squeeze glutes",
          "tag_ids" => ["", to_string(iso.id)],
          "videos" => %{"0" => %{"url" => "https://youtu.be/x?t=10", "label" => "cues"}}
        }
      }

      assert {:ok, show, _html} =
               view |> form("#movement-form") |> render_submit(params) |> follow_redirect(conn)

      assert has_element?(show, "#movement-notes", "squeeze glutes")
      assert has_element?(show, "#movement-tags", "isometric")
      assert has_element?(show, ~s|#movement-videos a[href="https://youtu.be/x?t=10"]|, "cues")
    end

    test "a duplicate name is reported", %{conn: conn} do
      movement_fixture(%{name: "Plank"})
      {:ok, view, _html} = live(conn, ~p"/movements/new")

      assert view
             |> form("#movement-form", %{"movement" => %{"name" => "plank"}})
             |> render_submit() =~
               "has already been taken"
    end

    test "edits keep untouched tags", %{conn: conn} do
      tag = tag_fixture()
      movement = movement_fixture(%{name: "Row", tag_ids: [tag.id]})
      {:ok, view, _html} = live(conn, ~p"/movements/#{movement}/edit")

      assert has_element?(view, "#tag-#{tag.id}[checked]")

      assert {:ok, _show, _html} =
               view
               |> form("#movement-form", %{"movement" => %{"name" => "One-arm Row"}})
               |> render_submit()
               |> follow_redirect(conn, ~p"/movements/#{movement}")

      assert %{name: "One-arm Row", tags: [_]} = Catalog.get_movement!(movement.id)
    end
  end

  describe "show" do
    test "shows recent sets and links to plan and log it today", %{conn: conn} do
      set = completed_set_fixture(%{reps: 7})
      {:ok, view, _html} = live(conn, ~p"/movements/#{set.movement_id}")

      assert has_element?(view, "#recent-sets", "7 reps")
      assert has_element?(view, ~s|#plan-movement[href$="/plan?movement_id=#{set.movement_id}"]|)
      assert has_element?(view, ~s|#log-movement[href$="/log?movement_id=#{set.movement_id}"]|)
    end

    test "a movement with history cannot be deleted", %{conn: conn} do
      set = completed_set_fixture()
      {:ok, view, _html} = live(conn, ~p"/movements/#{set.movement_id}")

      assert view |> element("#delete-movement") |> render_click() =~
               "Movement has completed sets"
    end

    test "an unused movement can be deleted", %{conn: conn} do
      movement = movement_fixture()
      {:ok, view, _html} = live(conn, ~p"/movements/#{movement}")
      assert has_element?(view, "#no-recent")

      assert {:ok, _index, html} =
               view
               |> element("#delete-movement")
               |> render_click()
               |> follow_redirect(conn, ~p"/movements")

      assert html =~ "Movement deleted."
    end
  end
end
