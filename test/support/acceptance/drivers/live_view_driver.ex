defmodule Sturdy.Acceptance.Drivers.LiveViewDriver do
  @moduledoc """
  Drives Sturdy in-process through `Phoenix.LiveViewTest`: the real router,
  LiveViews, and database, without a browser. Fast, but there is no
  JavaScript, so where the page relies on the client (JS commands, confirm
  dialogs) this driver sends the event the client would have sent.

  Every step starts from a freshly mounted page, so the only state is a conn.
  """

  @behaviour Sturdy.Acceptance.Driver

  import Phoenix.ConnTest, only: [build_conn: 0, get: 2]
  import Phoenix.LiveViewTest

  alias Sturdy.Acceptance.WebUI

  @endpoint SturdyWeb.Endpoint

  @impl true
  def start, do: %{conn: build_conn()}

  @impl true
  def stop(_state), do: :ok

  @impl true
  def create_tag_category(%{conn: conn}, name) do
    {:ok, view, _html} = live(conn, WebUI.tags_path())
    view |> form(WebUI.category_form(), WebUI.category_params(name)) |> render_submit()
    :ok
  end

  @impl true
  def create_tag(%{conn: conn}, category, name) do
    {:ok, view, html} = live(conn, WebUI.tags_path())
    view |> form(WebUI.tag_form(), WebUI.tag_params(html, category, name)) |> render_submit()
    :ok
  end

  @impl true
  def create_movement(%{conn: conn}, movement) do
    {:ok, view, _html} = live(conn, WebUI.new_movement_path())

    # "Add video" is a client-side JS command; send the change it dispatches.
    video_slots = %{
      "movement" => %{
        "name" => movement.name,
        "videos_sort" => Enum.map(movement.videos, fn _video -> "new" end)
      }
    }

    html = render_change(view, "validate", video_slots)

    outcome = fn
      {:error, {:live_redirect, _to}} -> :ok
      html when is_binary(html) -> :rejected
    end

    view
    |> form(WebUI.movement_form(), WebUI.movement_params(html, movement))
    |> render_submit()
    |> outcome.()
  end

  @impl true
  def plan_sets(%{conn: conn}, plan) do
    start = WebUI.plan_start(plan)
    {:ok, view, _html} = live(conn, WebUI.plan_path(start))
    {to_add, to_remove} = WebUI.date_changes(plan, start)

    Enum.each(to_add, fn date ->
      view
      |> form(WebUI.plan_form(), %{WebUI.new_date_field() => Date.to_iso8601(date)})
      |> render_change()
    end)

    Enum.each(to_remove, &(view |> element(WebUI.remove_date_button(&1)) |> render_click()))

    view
    |> form(WebUI.plan_form(), WebUI.plan_params(render(view), plan))
    |> render_submit()
    |> left_form!()
  end

  @impl true
  def log_set(%{conn: conn}, on, fields) do
    {:ok, view, html} = live(conn, WebUI.log_path(on))

    view
    |> form(WebUI.log_form(), WebUI.set_params(html, "completed_set", fields))
    |> render_submit()
    |> left_form!()
  end

  @impl true
  def act(%{conn: conn}, on, ref, action) do
    {:ok, view, _html} = live(conn, WebUI.day_path(on))
    view |> element(WebUI.entry_action(ref, action)) |> render_click()
    :ok
  end

  @impl true
  def edit(%{conn: conn}, on, ref, fields) do
    {:ok, day, _html} = live(conn, WebUI.day_path(on))

    {:ok, view, html} =
      day |> element(WebUI.entry_action(ref, :edit)) |> render_click() |> follow_redirect(conn)

    view
    |> form(WebUI.edit_screen(), WebUI.set_params(html, WebUI.edit_prefix(html), fields))
    |> render_submit()
    |> left_form!()
  end

  @impl true
  def read_day(%{conn: conn}, on) do
    {:ok, _view, html} = live(conn, WebUI.day_path(on))
    WebUI.day(html)
  end

  @impl true
  def read_movements(%{conn: conn}) do
    {:ok, _view, html} = live(conn, WebUI.movements_path())
    WebUI.movements(html)
  end

  @impl true
  def read_movements_tagged(%{conn: conn}, tag) do
    {:ok, view, html} = live(conn, WebUI.movements_path())
    view |> element(WebUI.tag_filter(html, tag)) |> render_click() |> WebUI.movements()
  end

  @impl true
  def read_movement(%{conn: conn}, name) do
    {:ok, index, _html} = live(conn, WebUI.movements_path())

    {:ok, _view, html} =
      index |> element(WebUI.movement_link(name)) |> render_click() |> follow_redirect(conn)

    WebUI.movement(html)
  end

  # A saved form navigates away; staying put means the system refused it.
  defp left_form!({:error, {:live_redirect, _to}}), do: :ok

  defp left_form!(html) when is_binary(html),
    do: raise("the form was not accepted: #{inspect(WebUI.errors(html))}")
end
