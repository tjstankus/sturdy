defmodule SturdyWeb.DayLive do
  @moduledoc """
  The primary screen: one day's planned and completed sets, grouped by movement.
  """

  use SturdyWeb, :live_view

  import SturdyWeb.SetComponents

  alias Sturdy.Training
  alias Sturdy.Training.Day.Entry
  alias SturdyWeb.DateParam
  alias SturdyWeb.Errors
  alias SturdyWeb.SetFormat

  # Each entry action: how to load its record, and what to do with it.
  @actions %{
    "complete" => {&Training.get_planned_set!/1, &Training.complete_planned_set/1},
    "skip" => {&Training.get_planned_set!/1, &Training.skip_planned_set/1},
    "delete_plan" => {&Training.get_planned_set!/1, &Training.delete_planned_set/1},
    "delete_completed" => {&Training.get_completed_set!/1, &Training.delete_completed_set/1}
  }
  @action_names Map.keys(@actions)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, stream_configure(socket, :groups, dom_id: &"movement-#{&1.movement.id}")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    case DateParam.fetch(params) do
      {:ok, date} ->
        {:noreply, socket |> assign(date: date, page_title: DateParam.label(date)) |> load_day()}

      :error ->
        {:noreply, socket |> put_flash(:error, "That isn't a date.") |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event(action, %{"id" => id}, socket) when action in @action_names do
    {fetch, act} = Map.fetch!(@actions, action)

    socket =
      case id |> fetch.() |> act.() do
        {:ok, _record} -> socket
        {:error, changeset} -> put_flash(socket, :error, Errors.summary(changeset))
      end

    {:noreply, load_day(socket)}
  end

  defp load_day(socket),
    do: stream(socket, :groups, Training.day(socket.assigns.date), reset: true)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} title={DateParam.label(@date)} tab={:day}>
      <:actions>
        <.link
          id="prev-day"
          patch={~p"/days/#{Date.add(@date, -1)}"}
          class="rounded-full p-2 active:bg-base-200"
          aria-label="Previous day"
        >
          <.icon name="hero-chevron-left" class="size-6" />
        </.link>
        <.link
          id="next-day"
          patch={~p"/days/#{Date.add(@date, 1)}"}
          class="rounded-full p-2 active:bg-base-200"
          aria-label="Next day"
        >
          <.icon name="hero-chevron-right" class="size-6" />
        </.link>
      </:actions>

      <p class="mb-3 text-sm text-base-content/60">
        {Calendar.strftime(@date, "%A, %B %-d, %Y")}
        <.link
          :if={@page_title != "Today"}
          id="today-link"
          patch={~p"/"}
          class="ml-2 link link-primary"
        >
          Go to today
        </.link>
      </p>

      <div id="groups" phx-update="stream" class="space-y-3">
        <div
          id="empty-day"
          class="hidden only:block rounded-box bg-base-100 p-6 text-center text-base-content/60"
        >
          Nothing planned or done yet.
        </div>
        <section
          :for={{dom_id, group} <- @streams.groups}
          id={dom_id}
          data-movement={group.movement.name}
          class="overflow-hidden rounded-box bg-base-100 shadow-sm"
        >
          <header class="flex items-baseline justify-between px-4 pt-3 pb-1">
            <.movement_link movement={group.movement} />
            <span class="text-xs text-base-content/60">
              {Enum.count(group.entries, &(&1.state == :done))}/{length(group.entries)} done
            </span>
          </header>
          <ul class="divide-y divide-base-200">
            <.entry :for={entry <- group.entries} entry={entry} />
          </ul>
        </section>
      </div>

      <div class="fixed inset-x-0 bottom-[calc(4rem+env(safe-area-inset-bottom))] z-10 pointer-events-none">
        <div class="mx-auto grid max-w-xl grid-cols-2 gap-3 px-4 pb-3">
          <.link
            id="plan-sets"
            navigate={~p"/days/#{@date}/plan"}
            class="btn btn-lg btn-outline bg-base-100 pointer-events-auto shadow"
          >
            <.icon name="hero-calendar" class="size-5" /> Plan
          </.link>
          <.link
            id="log-set"
            navigate={~p"/days/#{@date}/log"}
            class="btn btn-lg btn-primary pointer-events-auto shadow"
          >
            <.icon name="hero-plus" class="size-5" /> Log set
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end

  # One row per entry; each state renders its own controls. The data-*
  # attributes describe the entry for machines (e.g. acceptance-test drivers).
  attr :entry, Entry, required: true

  defp entry(%{entry: %Entry{state: :pending}} = assigns) do
    ~H"""
    <li
      id={"planned-#{@entry.planned_set.id}"}
      data-state="pending"
      data-side={@entry.planned_set.side}
      data-summary={SetFormat.summary(@entry.planned_set)}
      class="flex items-center gap-3 px-3 py-2"
    >
      <button
        id={"complete-#{@entry.planned_set.id}"}
        phx-click="complete"
        phx-value-id={@entry.planned_set.id}
        data-action="mark_done"
        class="grid size-11 shrink-0 place-items-center rounded-full border-2 border-base-300 text-base-content/30 transition active:scale-95 active:border-primary active:text-primary"
        aria-label="Mark done"
      >
        <.icon name="hero-check" class="size-6" />
      </button>
      <div class="min-w-0 flex-1">
        <p>{SetFormat.summary(@entry.planned_set)}</p>
        <p :if={@entry.planned_set.notes} class="truncate text-xs text-base-content/60">
          {@entry.planned_set.notes}
        </p>
      </div>
      <.link
        id={"edit-plan-#{@entry.planned_set.id}"}
        navigate={~p"/planned/#{@entry.planned_set}/edit"}
        data-action="edit"
        class="p-2 text-base-content/60"
        aria-label="Edit plan"
      >
        <.icon name="hero-pencil-square" class="size-5" />
      </.link>
      <button
        id={"skip-#{@entry.planned_set.id}"}
        phx-click="skip"
        phx-value-id={@entry.planned_set.id}
        data-action="skip"
        data-confirm="Skip this set? Skipping is final."
        class="p-2 text-base-content/60"
        aria-label="Skip"
      >
        <.icon name="hero-forward" class="size-5" />
      </button>
      <button
        id={"delete-plan-#{@entry.planned_set.id}"}
        phx-click="delete_plan"
        phx-value-id={@entry.planned_set.id}
        data-action="delete"
        data-confirm="Delete this planned set?"
        class="p-2 text-base-content/60"
        aria-label="Delete plan"
      >
        <.icon name="hero-trash" class="size-5" />
      </button>
    </li>
    """
  end

  defp entry(%{entry: %Entry{state: :done, completed_set: completed_set}} = assigns) do
    # A done entry either completes a plan (undo returns the plan to pending)
    # or is unplanned work (removing it deletes it).
    origin = fn
      %Entry{planned_set: nil} ->
        %{
          planned: nil,
          note: "unplanned",
          action: "delete",
          label: "Delete",
          confirm: "Delete this completed set?"
        }

      %Entry{planned_set: planned_set} ->
        planned = SetFormat.summary(planned_set)

        %{
          planned: planned,
          note: planned != SetFormat.summary(completed_set) && "planned #{planned}",
          action: "undo",
          label: "Undo",
          confirm: "Undo? The plan goes back to pending."
        }
    end

    assigns =
      assign(assigns,
        origin: origin.(assigns.entry),
        local_time: Sturdy.LocalTime.to_local(completed_set.completed_at)
      )

    ~H"""
    <li
      id={"completed-#{@entry.completed_set.id}"}
      data-state="done"
      data-side={@entry.completed_set.side}
      data-summary={SetFormat.summary(@entry.completed_set)}
      data-planned={@origin.planned}
      data-time={Calendar.strftime(@local_time, "%H:%M")}
      class="flex items-center gap-3 px-3 py-2"
    >
      <span class="grid size-11 shrink-0 place-items-center rounded-full bg-success text-success-content">
        <.icon name="hero-check" class="size-6" />
      </span>
      <.link
        navigate={~p"/completed/#{@entry.completed_set}/edit"}
        data-action="edit"
        class="min-w-0 flex-1"
      >
        <p>{SetFormat.summary(@entry.completed_set)}</p>
        <p class="truncate text-xs text-base-content/60">
          {Calendar.strftime(@local_time, "%-I:%M %p")}
          <span :if={@origin.note} class="italic">· {@origin.note}</span>
          <span :if={@entry.completed_set.notes}>· {@entry.completed_set.notes}</span>
        </p>
      </.link>
      <button
        id={"undo-#{@entry.completed_set.id}"}
        phx-click="delete_completed"
        phx-value-id={@entry.completed_set.id}
        data-action={@origin.action}
        data-confirm={@origin.confirm}
        class="p-2 text-base-content/60"
        aria-label={@origin.label}
      >
        <.icon name="hero-arrow-uturn-left" class="size-5" />
      </button>
    </li>
    """
  end

  defp entry(%{entry: %Entry{state: :skipped}} = assigns) do
    ~H"""
    <li
      id={"planned-#{@entry.planned_set.id}"}
      data-state="skipped"
      data-side={@entry.planned_set.side}
      data-summary={SetFormat.summary(@entry.planned_set)}
      class="flex items-center gap-3 px-3 py-2 opacity-50"
    >
      <span class="grid size-11 shrink-0 place-items-center rounded-full border-2 border-dashed border-base-300">
        <.icon name="hero-forward" class="size-5" />
      </span>
      <p class="flex-1 line-through">{SetFormat.summary(@entry.planned_set)}</p>
      <button
        id={"delete-plan-#{@entry.planned_set.id}"}
        phx-click="delete_plan"
        phx-value-id={@entry.planned_set.id}
        data-action="delete"
        data-confirm="Delete this skipped plan?"
        class="p-2"
        aria-label="Delete plan"
      >
        <.icon name="hero-trash" class="size-5" />
      </button>
    </li>
    """
  end
end
