defmodule SturdyWeb.MovementLive.Form do
  @moduledoc """
  Creates or edits a movement with its tags and videos.
  """

  use SturdyWeb, :live_view

  alias Sturdy.Catalog

  @impl true
  def mount(params, _session, socket) do
    {movement, page_title, back} =
      case params do
        %{"id" => id} ->
          movement = Catalog.get_movement!(id)
          {movement, "Edit movement", ~p"/movements/#{movement}"}

        _new ->
          {Catalog.new_movement(), "New movement", ~p"/movements"}
      end

    # Seed the virtual tag_ids so untouched checkboxes are "no change".
    movement = %{movement | tag_ids: Enum.map(movement.tags, & &1.id)}

    {:ok,
     socket
     |> assign(
       page_title: page_title,
       back: back,
       movement: movement,
       categories: Catalog.list_tag_categories()
     )
     |> assign(form: to_form(Catalog.change_movement(movement)))}
  end

  @impl true
  def handle_event("validate", %{"movement" => params}, socket) do
    changeset = Catalog.change_movement(socket.assigns.movement, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"movement" => params}, socket) do
    case Catalog.save_movement(socket.assigns.movement, params) do
      {:ok, movement} ->
        {:noreply,
         socket
         |> put_flash(:info, "Movement saved.")
         |> push_navigate(to: ~p"/movements/#{movement}")}

      {:error, changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(
        assigns,
        :selected_tag_ids,
        Enum.map(assigns.form[:tag_ids].value || [], &to_string/1)
      )

    ~H"""
    <Layouts.app
      flash={@flash}
      title={@page_title}
      tab={:movements}
      back={@back}
    >
      <.form for={@form} id="movement-form" phx-change="validate" phx-submit="save" class="space-y-4">
        <section class="rounded-box bg-base-100 p-4">
          <.input
            field={@form[:name]}
            label="Name"
            placeholder="e.g. Paused Bench Press"
            autocomplete="off"
          />
          <.input field={@form[:notes]} type="textarea" label="Notes & cues" rows="3" />
        </section>

        <section class="rounded-box bg-base-100 p-4">
          <h2 class="mb-2 font-semibold">Tags</h2>
          <input type="hidden" name="movement[tag_ids][]" value="" />
          <p :if={@categories == []} class="text-sm text-base-content/60">
            No tags yet. <.link navigate={~p"/tags"} class="link link-primary">Add some</.link>
          </p>
          <fieldset :for={category <- @categories} :if={category.tags != []} class="mb-3">
            <legend class="mb-1 text-sm text-base-content/60">{category.name}</legend>
            <div class="flex flex-wrap gap-2">
              <label
                :for={tag <- category.tags}
                class="btn btn-sm has-checked:btn-primary"
              >
                <input
                  id={"tag-#{tag.id}"}
                  type="checkbox"
                  name="movement[tag_ids][]"
                  value={tag.id}
                  checked={to_string(tag.id) in @selected_tag_ids}
                  class="hidden"
                />
                {tag.name}
              </label>
            </div>
          </fieldset>
        </section>

        <section class="rounded-box bg-base-100 p-4">
          <h2 class="mb-2 font-semibold">Videos</h2>
          <.inputs_for :let={video} field={@form[:videos]}>
            <div id={"video-#{video.index}"} class="mb-3 rounded-box border border-base-300 p-3">
              <input type="hidden" name="movement[videos_sort][]" value={video.index} />
              <.input field={video[:url]} type="url" label="URL" placeholder="https://…" />
              <.input field={video[:label]} label="Label (optional)" />
              <button
                type="button"
                id={"remove-video-#{video.index}"}
                name="movement[videos_drop][]"
                value={video.index}
                phx-click={JS.dispatch("change")}
                class="btn btn-ghost btn-xs text-error"
              >
                Remove
              </button>
            </div>
          </.inputs_for>
          <input type="hidden" name="movement[videos_drop][]" />
          <button
            type="button"
            id="add-video"
            name="movement[videos_sort][]"
            value="new"
            phx-click={JS.dispatch("change")}
            class="btn btn-sm btn-outline"
          >
            <.icon name="hero-plus" class="size-4" /> Add video
          </button>
        </section>

        <button
          id="save-movement"
          type="submit"
          class="btn btn-primary btn-lg w-full"
          phx-disable-with="Saving…"
        >
          Save
        </button>
      </.form>
    </Layouts.app>
    """
  end
end
