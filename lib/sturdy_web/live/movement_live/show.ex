defmodule SturdyWeb.MovementLive.Show do
  @moduledoc """
  A movement's notes, tags, videos, and recent history.
  """

  use SturdyWeb, :live_view

  alias Sturdy.Catalog
  alias Sturdy.LocalTime
  alias Sturdy.Training
  alias SturdyWeb.Errors
  alias SturdyWeb.SetFormat

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    movement = Catalog.get_movement!(id)

    {:ok,
     socket
     |> assign(page_title: movement.name, movement: movement, today: LocalTime.today())
     |> stream(:recent, Training.recent_completed_sets(movement.id))}
  end

  @impl true
  def handle_event("delete", _params, socket) do
    case Catalog.delete_movement(socket.assigns.movement) do
      {:ok, _movement} ->
        {:noreply,
         socket |> put_flash(:info, "Movement deleted.") |> push_navigate(to: ~p"/movements")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, Errors.summary(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} title={@movement.name} tab={:movements} back={~p"/movements"}>
      <:actions>
        <.link
          id="edit-movement"
          navigate={~p"/movements/#{@movement}/edit"}
          class="btn btn-ghost btn-sm"
        >
          Edit
        </.link>
      </:actions>

      <div class="mb-4 grid grid-cols-2 gap-3">
        <.link
          id="plan-movement"
          navigate={~p"/days/#{@today}/plan?movement_id=#{@movement.id}"}
          class="btn btn-outline btn-lg bg-base-100"
        >
          <.icon name="hero-calendar" class="size-5" /> Plan
        </.link>
        <.link
          id="log-movement"
          navigate={~p"/days/#{@today}/log?movement_id=#{@movement.id}"}
          class="btn btn-primary btn-lg"
        >
          <.icon name="hero-plus" class="size-5" /> Log
        </.link>
      </div>

      <section class="mb-3 space-y-3 rounded-box bg-base-100 p-4">
        <p :if={@movement.notes} id="movement-notes" class="whitespace-pre-line">{@movement.notes}</p>
        <ul :if={@movement.tags != []} id="movement-tags" class="flex flex-wrap gap-2">
          <li :for={tag <- @movement.tags} class="badge badge-soft">
            <span class="text-base-content/50">{tag.tag_category.name}:</span> {tag.name}
          </li>
        </ul>
        <ul :if={@movement.videos != []} id="movement-videos" class="space-y-1">
          <li :for={video <- @movement.videos}>
            <a
              href={video.url}
              target="_blank"
              rel="noopener noreferrer"
              class="link link-primary inline-flex items-center gap-1"
            >
              <.icon name="hero-play-circle" class="size-5" />
              {video.label || URI.parse(video.url).host}
            </a>
          </li>
        </ul>
      </section>

      <h2 class="mb-2 px-1 text-sm font-semibold text-base-content/60">Recent sets</h2>
      <ul
        id="recent-sets"
        phx-update="stream"
        class="mb-6 divide-y divide-base-200 overflow-hidden rounded-box bg-base-100"
      >
        <li id="no-recent" class="hidden only:block p-4 text-center text-base-content/60">
          None yet.
        </li>
        <li
          :for={{dom_id, set} <- @streams.recent}
          id={dom_id}
          class="flex justify-between gap-3 px-4 py-2"
        >
          <span>{SetFormat.summary(set)}</span>
          <span class="shrink-0 text-sm text-base-content/60">
            {set.completed_at |> LocalTime.to_local() |> Calendar.strftime("%b %-d")}
          </span>
        </li>
      </ul>

      <button
        id="delete-movement"
        phx-click="delete"
        data-confirm="Delete this movement?"
        class="btn btn-ghost btn-sm w-full text-error"
      >
        Delete movement
      </button>
    </Layouts.app>
    """
  end
end
