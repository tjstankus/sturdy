defmodule SturdyWeb.DayLiveTest do
  use SturdyWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Sturdy.CatalogFixtures
  import Sturdy.TrainingFixtures

  alias Sturdy.LocalTime
  alias Sturdy.Training

  @date ~D[2026-11-10]

  test "today is the home page, empty at first", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#empty-day")
    assert has_element?(view, "#tab-day[aria-current=page]")
    assert has_element?(view, ~s|#plan-sets[href="/days/#{LocalTime.today()}/plan"]|)
    refute has_element?(view, "#today-link")
  end

  test "an invalid date goes back to today", %{conn: conn} do
    assert {:error, {:live_redirect, %{to: "/", flash: %{"error" => _}}}} =
             live(conn, ~p"/days/nope")
  end

  test "prev and next move a day at a time", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/days/#{@date}")

    view |> element("#next-day") |> render_click()
    assert_patch(view, ~p"/days/2026-11-11")
    view |> element("#prev-day") |> render_click()
    assert_patch(view, ~p"/days/2026-11-10")
    assert has_element?(view, "#today-link")
  end

  test "plans for the day are grouped by movement", %{conn: conn} do
    bench = movement_fixture(%{name: "Bench Press"})
    plan = planned_set_fixture(%{movement_id: bench.id, planned_on: @date, notes: "slow"})

    {:ok, view, _html} = live(conn, ~p"/days/#{@date}")

    assert has_element?(view, "#movement-#{bench.id}", "Bench Press")
    assert has_element?(view, "#planned-#{plan.id}", "5 reps")
    assert has_element?(view, "#planned-#{plan.id}", "slow")
    assert has_element?(view, "#movement-#{bench.id}", "0/1 done")
  end

  test "tapping done completes the plan; undo makes it pending again", %{conn: conn} do
    plan = planned_set_fixture(%{planned_on: @date})
    {:ok, view, _html} = live(conn, ~p"/days/#{@date}")

    view |> element("#complete-#{plan.id}") |> render_click()

    [completed] = Training.recent_completed_sets(plan.movement_id)
    assert has_element?(view, "#completed-#{completed.id}")
    refute has_element?(view, "#planned-#{plan.id}")

    assert has_element?(
             view,
             ~s|#completed-#{completed.id} a[href="/completed/#{completed.id}/edit"]|
           )

    view |> element("#undo-#{completed.id}") |> render_click()
    assert has_element?(view, "#planned-#{plan.id}")
  end

  test "a done set that differed from the plan shows the plan", %{conn: conn} do
    plan = planned_set_fixture(%{planned_on: @date, reps: 5})
    {:ok, done} = Training.complete_planned_set(plan, ~U[2026-11-10 15:00:00Z])
    {:ok, _} = Training.update_completed_set(done, %{reps: 4, notes: "tired"})

    {:ok, view, _html} = live(conn, ~p"/days/#{@date}")

    assert has_element?(view, "#completed-#{done.id}", "4 reps")
    assert has_element?(view, "#completed-#{done.id}", "planned 5 reps")
    assert has_element?(view, "#completed-#{done.id}", "tired")
  end

  test "unplanned sets show on their local day", %{conn: conn} do
    hold =
      completed_set_fixture(%{reps: nil, duration_s: 30, completed_at: ~U[2026-11-10 15:00:00Z]})

    {:ok, view, _html} = live(conn, ~p"/days/#{@date}")

    assert has_element?(view, "#completed-#{hold.id}", "30s")
    assert has_element?(view, "#completed-#{hold.id}", "unplanned")

    view |> element("#undo-#{hold.id}") |> render_click()
    refute has_element?(view, "#completed-#{hold.id}")
  end

  test "skip and delete", %{conn: conn} do
    [skip, delete] = for _ <- 1..2, do: planned_set_fixture(%{planned_on: @date})
    {:ok, view, _html} = live(conn, ~p"/days/#{@date}")

    view |> element("#skip-#{skip.id}") |> render_click()
    assert has_element?(view, "#planned-#{skip.id}.opacity-50")
    refute has_element?(view, "#complete-#{skip.id}")

    view |> element("#delete-plan-#{delete.id}") |> render_click()
    refute has_element?(view, "#planned-#{delete.id}")

    view |> element("#delete-plan-#{skip.id}") |> render_click()
    assert has_element?(view, "#empty-day")
  end

  test "rule violations are reported, not crashed on", %{conn: conn} do
    plan = planned_set_fixture(%{planned_on: @date})
    {:ok, view, _html} = live(conn, ~p"/days/#{@date}")
    {:ok, _} = Training.complete_planned_set(plan)

    assert render_click(view, "delete_plan", %{"id" => plan.id}) =~
             "Planned set has been completed"
  end
end
