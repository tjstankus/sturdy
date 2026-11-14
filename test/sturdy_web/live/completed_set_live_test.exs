defmodule SturdyWeb.CompletedSetLiveTest do
  # The configured timezone is America/New_York (UTC-5 in November).
  use SturdyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Sturdy.CatalogFixtures
  import Sturdy.TrainingFixtures

  alias Sturdy.LocalTime
  alias Sturdy.Training

  test "logging unplanned work in local time", %{conn: conn} do
    movement = movement_fixture()
    {:ok, view, _html} = live(conn, ~p"/days/2026-11-10/log?movement_id=#{movement.id}")

    # Another day defaults to its local noon.
    assert has_element?(
             view,
             ~s|input[name="completed_set[completed_at]"][value="2026-11-10T12:00"]|
           )

    assert has_element?(view, ~s|option[value="#{movement.id}"][selected]|)

    params = %{
      "completed_set" => %{
        "movement_id" => movement.id,
        "duration_s" => "30",
        "side" => "left",
        "completed_at" => "2026-11-11T00:30"
      }
    }

    assert {:ok, _day, html} =
             view
             |> form("#completed-set-form", params)
             |> render_submit()
             |> follow_redirect(conn, ~p"/days/2026-11-11")

    assert html =~ "Set saved."

    assert [%{completed_at: ~U[2026-11-11 05:30:00Z], side: :left}] =
             Training.recent_completed_sets(movement.id)
  end

  test "today's log defaults to now", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/days/#{LocalTime.today()}/log")

    assert has_element?(
             view,
             ~s|input[name="completed_set[completed_at]"][value^="#{LocalTime.today()}T"]|
           )
  end

  test "validation errors are shown", %{conn: conn} do
    movement = movement_fixture()
    {:ok, view, _html} = live(conn, ~p"/days/2026-11-10/log")

    assert view
           |> form("#completed-set-form", %{
             "completed_set" => %{"movement_id" => movement.id, "weight_lb" => "50"}
           })
           |> render_change() =~
             "enter reps, duration, or distance"

    # Sent directly: the form helper would keep the select's chosen movement.
    params = %{"movement_id" => "", "reps" => "5", "completed_at" => "2026-11-10T12:00"}
    assert render_submit(view, "save", %{"completed_set" => params}) =~ "can&#39;t be blank"
  end

  test "an invalid date goes back to today", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/days/bad/log")
  end

  test "editing a completed plan keeps its movement and side", %{conn: conn} do
    plan = planned_set_fixture(%{planned_on: ~D[2026-11-10], side: :right})
    {:ok, done} = Training.complete_planned_set(plan, ~U[2026-11-11 15:00:00Z])
    {:ok, view, _html} = live(conn, ~p"/completed/#{done}/edit")

    assert has_element?(view, "#planned-movement", "R")
    refute has_element?(view, ~s|select[name="completed_set[movement_id]"]|)
    refute has_element?(view, ~s|select[name="completed_set[side]"]|)

    assert has_element?(
             view,
             ~s|input[name="completed_set[completed_at]"][value="2026-11-11T10:00"]|
           )

    # Back to the plan's day, not the day it was done.
    assert {:ok, _day, _html} =
             view
             |> form("#completed-set-form", %{"completed_set" => %{"reps" => "4"}})
             |> render_submit()
             |> follow_redirect(conn, ~p"/days/2026-11-10")

    assert %{reps: 4, side: :right} = Training.get_completed_set!(done.id)
  end
end
