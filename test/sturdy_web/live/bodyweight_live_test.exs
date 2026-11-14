defmodule SturdyWeb.BodyweightLiveTest do
  use SturdyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Sturdy.Body

  test "add, correct, and delete entries", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/bodyweight")
    assert has_element?(view, "#no-entries")

    assert view
           |> form("#bodyweight-form", %{"bodyweight_entry" => %{"weight_lb" => "0"}})
           |> render_change() =~ "must be greater than"

    view
    |> form("#bodyweight-form", %{
      "bodyweight_entry" => %{"measured_on" => "2026-11-10", "weight_lb" => "180.5"}
    })
    |> render_submit()

    [entry] = Body.list_bodyweight_entries()
    assert has_element?(view, "#entries-#{entry.id}", "180.5 lb")

    assert view
           |> form("#bodyweight-form", %{
             "bodyweight_entry" => %{"measured_on" => "2026-11-10", "weight_lb" => "181"}
           })
           |> render_submit() =~
             "already has an entry"

    view |> element("#edit-entries-#{entry.id}") |> render_click()
    view |> element("#cancel-edit") |> render_click()
    refute has_element?(view, "#cancel-edit")

    view |> element("#edit-entries-#{entry.id}") |> render_click()

    view
    |> form("#bodyweight-form", %{"bodyweight_entry" => %{"weight_lb" => "179"}})
    |> render_submit()

    assert has_element?(view, "#entries-#{entry.id}", "179 lb")

    view |> element("#delete-entries-#{entry.id}") |> render_click()
    assert has_element?(view, "#no-entries")
  end
end
