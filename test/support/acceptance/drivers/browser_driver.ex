defmodule Sturdy.Acceptance.Drivers.BrowserDriver do
  @moduledoc """
  Drives Sturdy as its user does: a real (headless) Chrome, phone-sized,
  against the app served over HTTP, with JavaScript, websockets, and
  LiveView's client all in play.

  Each spec gets its own tab; the server and Chrome are shared by the run
  (`Sturdy.Acceptance.Browser.Runtime`). Every step starts by loading a page.
  """

  @behaviour Sturdy.Acceptance.Driver

  alias Sturdy.Acceptance.Browser.Page
  alias Sturdy.Acceptance.Browser.Runtime
  alias Sturdy.Acceptance.WebUI

  @impl true
  def start do
    %{base_url: base_url, cdp: cdp} = Runtime.ensure_started()
    %{base_url: base_url, page: Page.open(cdp)}
  end

  @impl true
  def stop(%{page: page}), do: Page.close(page)

  @impl true
  def create_tag_category(state, name) do
    state
    |> visit(WebUI.tags_path())
    |> Page.fill_form(WebUI.category_params(name))
    |> Page.submit(WebUI.category_form())

    :ok
  end

  @impl true
  def create_tag(state, category, name) do
    page = visit(state, WebUI.tags_path())

    page
    |> Page.fill_form(WebUI.tag_params(Page.html(page), category, name))
    |> Page.submit(WebUI.tag_form())

    :ok
  end

  @impl true
  def create_movement(state, movement) do
    page = visit(state, WebUI.new_movement_path())
    Enum.each(movement.videos, fn _video -> Page.click(page, WebUI.add_video_button()) end)

    page
    |> Page.fill_form(WebUI.movement_params(Page.html(page), movement))
    |> submit(WebUI.movement_form(), WebUI.movement_screen())
  end

  @impl true
  def plan_sets(state, plan) do
    start = WebUI.plan_start(plan)
    page = visit(state, WebUI.plan_path(start))
    {to_add, to_remove} = WebUI.date_changes(plan, start)

    Enum.each(to_add, &Page.fill_form(page, %{WebUI.new_date_field() => Date.to_iso8601(&1)}))
    Enum.each(to_remove, &Page.click(page, WebUI.remove_date_button(&1)))

    page
    |> Page.fill_form(WebUI.plan_params(Page.html(page), plan))
    |> submit!(WebUI.plan_form(), WebUI.day_screen())
  end

  @impl true
  def log_set(state, on, fields) do
    page = visit(state, WebUI.log_path(on))

    page
    |> Page.fill_form(WebUI.set_params(Page.html(page), "completed_set", fields))
    |> submit!(WebUI.log_form(), WebUI.day_screen())
  end

  @impl true
  def act(state, on, ref, action) do
    state |> visit(WebUI.day_path(on)) |> Page.click(WebUI.entry_action(ref, action))
    :ok
  end

  @impl true
  def edit(state, on, ref, fields) do
    page =
      state
      |> visit(WebUI.day_path(on))
      |> Page.click(WebUI.entry_action(ref, :edit))
      |> Page.wait_for(WebUI.edit_screen())

    html = Page.html(page)

    page
    |> Page.fill_form(WebUI.set_params(html, WebUI.edit_prefix(html), fields))
    |> submit!(WebUI.edit_screen(), WebUI.day_screen())
  end

  @impl true
  def read_day(state, on), do: state |> visit(WebUI.day_path(on)) |> Page.html() |> WebUI.day()

  @impl true
  def read_movements(state),
    do: state |> visit(WebUI.movements_path()) |> Page.html() |> WebUI.movements()

  @impl true
  def read_movements_tagged(state, tag) do
    page = visit(state, WebUI.movements_path())
    filter = WebUI.tag_filter(Page.html(page), tag)

    # The filter patches the URL; wait until the list reflects it.
    page
    |> Page.click(filter)
    |> Page.wait_for(WebUI.active_filter(filter))
    |> Page.html()
    |> WebUI.movements()
  end

  @impl true
  def read_movement(state, name) do
    state
    |> visit(WebUI.movements_path())
    |> Page.click(WebUI.movement_link(name))
    |> Page.wait_for(WebUI.movement_screen())
    |> Page.html()
    |> WebUI.movement()
  end

  defp visit(%{base_url: base_url, page: page}, path), do: Page.visit(page, base_url <> path)

  # Submits a form; the next screen's landmark means accepted, errors mean refused.
  defp submit(page, form, landmark) do
    outcomes = %{landmark => :ok, WebUI.refusal() => :rejected}

    page
    |> Page.submit(form)
    |> Page.wait_for_any([landmark, WebUI.refusal()])
    |> then(&Map.fetch!(outcomes, &1))
  end

  defp submit!(page, form, landmark) do
    accepted = fn
      :ok -> :ok
      :rejected -> raise "the form was not accepted: #{inspect(WebUI.errors(Page.html(page)))}"
    end

    page |> submit(form, landmark) |> accepted.()
  end
end
