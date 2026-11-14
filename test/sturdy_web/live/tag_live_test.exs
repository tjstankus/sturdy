defmodule SturdyWeb.TagLiveTest do
  use SturdyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Sturdy.CatalogFixtures

  test "add a category, then a tag in it", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/tags")
    refute has_element?(view, "#tag-form")

    assert view |> form("#category-form", %{"tag_category" => %{"name" => ""}}) |> render_submit() =~
             "can&#39;t be blank"

    view |> form("#category-form", %{"tag_category" => %{"name" => "muscle"}}) |> render_submit()
    assert has_element?(view, "section[id^=category-]", "muscle")
    assert has_element?(view, "section[id^=category-]", "No tags yet.")

    view |> form("#tag-form", %{"tag" => %{"name" => "glutes"}}) |> render_submit()
    assert has_element?(view, "[id^=tag-row-]", "glutes")

    assert view |> form("#tag-form", %{"tag" => %{"name" => "Glutes"}}) |> render_submit() =~
             "already exists in this category"
  end

  test "rename a tag, or cancel", %{conn: conn} do
    tag = tag_fixture(%{name: "pec"})
    {:ok, view, _html} = live(conn, ~p"/tags")

    view |> element("#tag-row-#{tag.id}-edit") |> render_click()
    view |> element("#tag-row-#{tag.id} button", "Cancel") |> render_click()
    refute has_element?(view, "#tag-row-#{tag.id}-form")

    view |> element("#tag-row-#{tag.id}-edit") |> render_click()

    assert view
           |> form("#tag-row-#{tag.id}-form", %{"item" => %{"name" => ""}})
           |> render_submit() =~ "can&#39;t be blank"

    view |> form("#tag-row-#{tag.id}-form", %{"item" => %{"name" => "pecs"}}) |> render_submit()

    assert has_element?(view, "#tag-row-#{tag.id}", "pecs")
  end

  test "rename a category", %{conn: conn} do
    category = tag_category_fixture(%{name: "musle"})
    {:ok, view, _html} = live(conn, ~p"/tags")

    view |> element("#category-row-#{category.id}-edit") |> render_click()

    view
    |> form("#category-row-#{category.id}-form", %{"item" => %{"name" => "muscle"}})
    |> render_submit()

    assert has_element?(view, "#category-row-#{category.id}", "muscle")
  end

  test "a category with tags can't be deleted until its tags are", %{conn: conn} do
    tag = tag_fixture()
    {:ok, view, _html} = live(conn, ~p"/tags")

    assert view |> element("#category-row-#{tag.tag_category_id}-delete") |> render_click() =~
             "Category still has tags"

    view |> element("#tag-row-#{tag.id}-delete") |> render_click()
    view |> element("#category-row-#{tag.tag_category_id}-delete") |> render_click()
    refute has_element?(view, "#category-#{tag.tag_category_id}")
  end
end
