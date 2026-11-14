defmodule SturdyWeb.PlannedSetLive.New do
  @moduledoc """
  Plans sets: one template, repeated N times, optionally per side, across
  chosen dates and/or a date range.
  """

  use SturdyWeb, :live_view

  import SturdyWeb.SetComponents

  alias Sturdy.Catalog
  alias Sturdy.Training
  alias Sturdy.Training.PlannedSet
  alias SturdyWeb.DateParam

  @impl true
  def mount(params, _session, socket) do
    case DateParam.fetch(params) do
      {:ok, date} ->
        {:ok,
         socket
         |> assign(date: date, page_title: "Plan sets", movements: Catalog.list_movements())
         |> assign_forms(
           %{"movement_id" => params["movement_id"]},
           %{"copies" => "1", "dates" => [Date.to_iso8601(date)]},
           nil
         )}

      :error ->
        {:ok, socket |> put_flash(:error, "That isn't a date.") |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("validate", %{"planned_set" => plan, "schedule" => schedule} = params, socket) do
    add_date = fn
      schedule, %{"new_date" => new_date} when new_date != "" ->
        Map.update(schedule, "dates", [new_date], &(&1 ++ [new_date]))

      schedule, _params ->
        schedule
    end

    {:noreply, assign_forms(socket, plan, add_date.(schedule, params), :validate)}
  end

  def handle_event("remove_date", %{"date" => date}, socket) do
    schedule = Map.update(socket.assigns.schedule_params, "dates", [], &List.delete(&1, date))
    {:noreply, assign_forms(socket, socket.assigns.plan_params, schedule, :validate)}
  end

  def handle_event("save", %{"planned_set" => plan, "schedule" => schedule}, socket) do
    case Training.schedule_planned_sets(plan, schedule) do
      {:ok, [first | _] = planned_sets} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           ngettext("Planned 1 set.", "Planned %{count} sets.", length(planned_sets))
         )
         |> push_navigate(to: ~p"/days/#{first.planned_on}")}

      {:error, _changeset} ->
        {:noreply, assign_forms(socket, plan, schedule, :insert)}
    end
  end

  defp assign_forms(socket, plan_params, schedule_params, action) do
    plan = Training.change_planned_set(%PlannedSet{planned_on: socket.assigns.date}, plan_params)
    schedule = Training.change_schedule(schedule_params)

    assign(socket,
      plan_params: plan_params,
      schedule_params: schedule_params,
      plan_form: to_form(plan, action: action),
      schedule_form: to_form(schedule, action: action),
      dates:
        schedule_params
        |> Map.get("dates", [])
        |> Enum.reject(&(&1 == ""))
        |> Enum.uniq()
        |> Enum.sort(),
      set_count: Training.schedule_set_count(schedule)
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} title="Plan sets" tab={:day} back={~p"/days/#{@date}"}>
      <p :if={@movements == []} id="no-movements" class="rounded-box bg-base-100 p-4">
        Add a movement first.
        <.link navigate={~p"/movements/new"} class="link link-primary">New movement</.link>
      </p>

      <.form for={@plan_form} id="plan-form" phx-change="validate" phx-submit="save" class="space-y-4">
        <section class="rounded-box bg-base-100 p-4">
          <.movement_select field={@plan_form[:movement_id]} movements={@movements} />
          <.metric_inputs
            form={@plan_form}
            side={@schedule_form[:per_side].value not in [true, "true"]}
          />
        </section>

        <section class="rounded-box bg-base-100 p-4">
          <h2 class="mb-2 font-semibold">Repeat</h2>
          <div class="grid grid-cols-2 items-end gap-x-3">
            <.input
              field={@schedule_form[:copies]}
              type="number"
              label="Sets"
              min="1"
              max="20"
              inputmode="numeric"
            />
            <.input field={@schedule_form[:per_side]} type="checkbox" label="Each side (L + R)" />
          </div>
        </section>

        <section class="rounded-box bg-base-100 p-4">
          <h2 class="mb-2 font-semibold">Dates</h2>
          <input type="hidden" name="schedule[dates][]" value="" />
          <input :for={date <- @dates} type="hidden" name="schedule[dates][]" value={date} />
          <ul id="chosen-dates" class="mb-2 flex flex-wrap gap-2">
            <li :for={date <- @dates} id={"date-#{date}"}>
              <button
                type="button"
                phx-click="remove_date"
                phx-value-date={date}
                class="badge badge-lg badge-primary badge-soft gap-1"
                aria-label={"Remove #{date}"}
              >
                {date |> Date.from_iso8601!() |> Calendar.strftime("%a %b %-d")}
                <.icon name="hero-x-mark" class="size-4" />
              </button>
            </li>
          </ul>
          <.input id="new-date" name="new_date" value="" type="date" label="Add a date" />
          <p class="mt-3 mb-1 text-sm text-base-content/60">…and/or every day in a range:</p>
          <div class="grid grid-cols-2 gap-x-3">
            <.input field={@schedule_form[:range_from]} type="date" label="From" />
            <.input field={@schedule_form[:range_to]} type="date" label="To" />
          </div>
          <p
            :for={msg <- Keyword.get_values(@schedule_form.errors, :dates)}
            class="text-sm text-error"
          >
            {translate_error(msg)}
          </p>
        </section>

        <button
          id="save-plan"
          type="submit"
          class="btn btn-primary btn-lg w-full"
          phx-disable-with="Planning…"
        >
          {ngettext("Plan 1 set", "Plan %{count} sets", @set_count)}
        </button>
      </.form>
    </Layouts.app>
    """
  end
end
