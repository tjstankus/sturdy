defmodule SturdyWeb.BodyweightLive.Index do
  @moduledoc """
  The bodyweight log: one entry per day. Tap an entry to correct it.
  """

  use SturdyWeb, :live_view

  alias Sturdy.Body
  alias Sturdy.Body.BodyweightEntry
  alias Sturdy.LocalTime
  alias SturdyWeb.Errors

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(page_title: "Bodyweight") |> reset_form() |> load()}
  end

  @impl true
  def handle_event("validate", %{"bodyweight_entry" => params}, socket) do
    changeset = Body.change_bodyweight_entry(socket.assigns.entry, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"bodyweight_entry" => params}, socket) do
    case Body.save_bodyweight_entry(socket.assigns.entry, params) do
      {:ok, _entry} -> {:noreply, socket |> reset_form() |> load()}
      {:error, changeset} -> {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("edit", %{"id" => id}, socket) do
    entry = Body.get_bodyweight_entry!(id)
    {:noreply, assign(socket, entry: entry, form: to_form(Body.change_bodyweight_entry(entry)))}
  end

  def handle_event("cancel", _params, socket), do: {:noreply, reset_form(socket)}

  def handle_event("delete", %{"id" => id}, socket) do
    socket =
      case id |> Body.get_bodyweight_entry!() |> Body.delete_bodyweight_entry() do
        {:ok, _entry} -> socket
        {:error, changeset} -> put_flash(socket, :error, Errors.summary(changeset))
      end

    {:noreply, socket |> reset_form() |> load()}
  end

  defp reset_form(socket) do
    entry = %BodyweightEntry{measured_on: LocalTime.today()}
    assign(socket, entry: entry, form: to_form(Body.change_bodyweight_entry(entry)))
  end

  defp load(socket), do: stream(socket, :entries, Body.list_bodyweight_entries(), reset: true)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} title="Bodyweight" tab={:body}>
      <section class="mb-4 rounded-box bg-base-100 p-4">
        <.form for={@form} id="bodyweight-form" phx-change="validate" phx-submit="save">
          <div class="grid grid-cols-2 gap-x-3">
            <.input field={@form[:measured_on]} type="date" label="Date" />
            <.input
              field={@form[:weight_lb]}
              type="number"
              label="Weight (lb)"
              step="0.1"
              inputmode="decimal"
            />
          </div>
          <div class="flex gap-2">
            <%= if @entry.id do %>
              <button id="save-bodyweight" type="submit" class="btn btn-primary flex-1">Update</button>
              <button id="cancel-edit" type="button" phx-click="cancel" class="btn btn-ghost">Cancel</button>
            <% else %>
              <button id="save-bodyweight" type="submit" class="btn btn-primary flex-1">Add</button>
            <% end %>
          </div>
        </.form>
      </section>

      <ul
        id="entries"
        phx-update="stream"
        class="divide-y divide-base-200 overflow-hidden rounded-box bg-base-100 shadow-sm"
      >
        <li id="no-entries" class="hidden only:block p-6 text-center text-base-content/60">
          No entries yet.
        </li>
        <li
          :for={{dom_id, entry} <- @streams.entries}
          id={dom_id}
          class="flex items-center gap-2 px-4 py-1"
        >
          <button
            id={"edit-#{dom_id}"}
            phx-click="edit"
            phx-value-id={entry.id}
            class="flex flex-1 justify-between py-2 text-left"
          >
            <span>{Calendar.strftime(entry.measured_on, "%a, %b %-d, %Y")}</span>
            <span class="font-semibold">{entry.weight_lb
            |> Decimal.normalize()
            |> Decimal.to_string(:normal)} lb</span>
          </button>
          <button
            id={"delete-#{dom_id}"}
            phx-click="delete"
            phx-value-id={entry.id}
            data-confirm="Delete this entry?"
            class="p-2 text-base-content/60"
            aria-label="Delete"
          >
            <.icon name="hero-trash" class="size-4" />
          </button>
        </li>
      </ul>
    </Layouts.app>
    """
  end
end
