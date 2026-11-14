defmodule SturdyWeb.PlannedSetLiveTest do
  use SturdyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Sturdy.CatalogFixtures
  import Sturdy.TrainingFixtures

  alias Sturdy.Repo
  alias Sturdy.Training
  alias Sturdy.Training.PlannedSet

  describe "plan sets" do
    test "asks for a movement first when there are none", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/days/2026-11-10/plan")
      assert has_element?(view, "#no-movements")
    end

    test "an invalid date goes back to today", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/"}}} = live(conn, ~p"/days/bad/plan")
    end

    test "3 sets per side on two dates", %{conn: conn} do
      movement = movement_fixture()
      {:ok, view, _html} = live(conn, ~p"/days/2026-11-10/plan?movement_id=#{movement.id}")

      assert has_element?(view, "#date-2026-11-10")
      assert has_element?(view, ~s|option[value="#{movement.id}"][selected]|)
      assert has_element?(view, "#plan-form select[name='planned_set[side]']")

      params = %{
        "planned_set" => %{"movement_id" => movement.id, "reps" => "8", "weight_lb" => "25"},
        "schedule" => %{"copies" => "3", "per_side" => "true", "dates" => ["2026-11-10"]}
      }

      view |> form("#plan-form") |> render_change(Map.put(params, "new_date", "2026-11-12"))

      assert has_element?(view, "#date-2026-11-12")
      assert has_element?(view, "#save-plan", "Plan 12 sets")
      refute has_element?(view, "#plan-form select[name='planned_set[side]']")

      params = put_in(params, ["schedule", "dates"], ["2026-11-10", "2026-11-12"])

      assert {:ok, _day, html} =
               view
               |> form("#plan-form")
               |> render_submit(params)
               |> follow_redirect(conn, ~p"/days/2026-11-10")

      assert html =~ "Planned 12 sets."
      assert Repo.aggregate(PlannedSet, :count) == 12
    end

    test "removing a date and invalid input show errors without saving", %{conn: conn} do
      movement = movement_fixture()
      {:ok, view, _html} = live(conn, ~p"/days/2026-11-10/plan")

      view |> element("#date-2026-11-10 button") |> render_click()
      refute has_element?(view, "#date-2026-11-10")
      assert render(view) =~ "pick at least one date"
      assert has_element?(view, "#save-plan", "Plan 0 sets")

      html =
        view
        |> form("#plan-form", %{
          "planned_set" => %{"movement_id" => movement.id},
          "schedule" => %{"range_from" => "2026-11-10", "range_to" => "2026-11-11"}
        })
        |> render_submit()

      assert html =~ "enter reps, duration, or distance"
      assert Repo.aggregate(PlannedSet, :count) == 0
    end
  end

  describe "edit a plan" do
    test "reschedules and changes the numbers", %{conn: conn} do
      plan = planned_set_fixture(%{planned_on: ~D[2026-11-10]})
      {:ok, view, _html} = live(conn, ~p"/planned/#{plan}/edit")

      refute has_element?(view, "#not-editable")

      assert view
             |> form("#planned-set-form", %{"planned_set" => %{"reps" => "0"}})
             |> render_change() =~ "must be greater than"

      assert {:ok, _day, html} =
               view
               |> form("#planned-set-form", %{
                 "planned_set" => %{"reps" => "3", "planned_on" => "2026-11-12"}
               })
               |> render_submit()
               |> follow_redirect(conn, ~p"/days/2026-11-12")

      assert html =~ "Plan updated."
      assert %{reps: 3} = Training.get_planned_set!(plan.id)
    end

    test "a done plan says so and refuses changes", %{conn: conn} do
      plan = planned_set_fixture()
      {:ok, _} = Training.complete_planned_set(plan)
      {:ok, view, _html} = live(conn, ~p"/planned/#{plan}/edit")

      assert has_element?(view, "#not-editable", "done")

      assert view
             |> form("#planned-set-form", %{"planned_set" => %{"reps" => "3"}})
             |> render_submit() =~ "Status is already done"
    end
  end
end
