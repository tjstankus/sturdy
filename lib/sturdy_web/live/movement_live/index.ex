defmodule SturdyWeb.MovementLive.Index do
  @moduledoc """
  All movements, filterable by tag.
  """

  use SturdyWeb, :live_view

  alias Sturdy.Catalog

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Movements", categories: Catalog.list_tag_categories())}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    tag_id =
      with tag when is_binary(tag) <- params["tag"],
           {id, ""} <- Integer.parse(tag) do
        id
      else
        _no_filter -> nil
      end

    {:noreply,
     socket
     |> assign(tag_id: tag_id)
     |> stream(:movements, Catalog.list_movements(tag_id: tag_id), reset: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} title="Movements" tab={:movements}>
      <:actions>
        <.link id="new-movement" navigate={~p"/movements/new"} class="btn btn-primary btn-sm">
          <.icon name="hero-plus" class="size-4" /> New
        </.link>
      </:actions>

      <nav id="tag-filter" class="-mx-4 mb-3 flex gap-2 overflow-x-auto px-4 pb-1">
        <.link
          id="filter-all"
          patch={~p"/movements"}
          class={[
            "badge badge-lg shrink-0",
            if(is_nil(@tag_id), do: "badge-primary", else: "badge-ghost")
          ]}
        >
          All
        </.link>
        <%= for category <- @categories, tag <- category.tags do %>
          <.link
            id={"filter-tag-#{tag.id}"}
            patch={~p"/movements?tag=#{tag.id}"}
            class={[
              "badge badge-lg shrink-0",
              if(tag.id == @tag_id, do: "badge-primary", else: "badge-ghost")
            ]}
          >
            {tag.name}
          </.link>
        <% end %>
      </nav>

      <ul
        id="movements"
        phx-update="stream"
        class="divide-y divide-base-200 overflow-hidden rounded-box bg-base-100 shadow-sm"
      >
        <li id="no-movements" class="hidden only:block p-6 text-center text-base-content/60">
          No movements yet.
        </li>
        <li :for={{dom_id, movement} <- @streams.movements} id={dom_id} data-movement={movement.name}>
          <.link
            navigate={~p"/movements/#{movement}"}
            class="flex items-center gap-3 px-4 py-3 active:bg-base-200"
          >
            <div class="min-w-0 flex-1">
              <p class="font-medium">{movement.name}</p>
              <p :if={movement.tags != []} class="truncate text-xs text-base-content/60">
                {Enum.map_join(movement.tags, ", ", & &1.name)}
              </p>
            </div>
            <.icon name="hero-chevron-right" class="size-5 text-base-content/40" />
          </.link>
        </li>
      </ul>
    </Layouts.app>
    """
  end
end
