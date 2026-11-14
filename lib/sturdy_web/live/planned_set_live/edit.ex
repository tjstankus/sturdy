defmodule SturdyWeb.PlannedSetLive.Edit do
  @moduledoc """
  Edits or reschedules one pending planned set.
  """

  use SturdyWeb, :live_view

  import SturdyWeb.SetComponents

  alias Sturdy.Catalog
  alias Sturdy.Training
  alias Sturdy.Training.PlannedSet
  alias SturdyWeb.Errors

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    planned_set = Training.get_planned_set!(id)

    {:ok,
     socket
     |> assign(
       page_title: "Edit plan",
       planned_set: planned_set,
       state: PlannedSet.state(planned_set),
       movements: Catalog.list_movements()
     )
     |> assign(form: to_form(Training.change_planned_set(planned_set)))}
  end

  @impl true
  def handle_event("validate", %{"planned_set" => params}, socket) do
    changeset = Training.change_planned_set(socket.assigns.planned_set, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"planned_set" => params}, socket) do
    case Training.update_planned_set(socket.assigns.planned_set, params) do
      {:ok, planned_set} ->
        {:noreply,
         socket
         |> put_flash(:info, "Plan updated.")
         |> push_navigate(to: ~p"/days/#{planned_set.planned_on}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> put_flash(:error, Errors.summary(changeset))
         |> assign(form: to_form(changeset))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      title="Edit plan"
      tab={:day}
      back={~p"/days/#{@planned_set.planned_on}"}
    >
      <p :if={@state != :pending} id="not-editable" class="mb-3 rounded-box bg-warning/20 p-3 text-sm">
        This plan is {@state}, so it can no longer be changed.
      </p>
      <.form for={@form} id="planned-set-form" phx-change="validate" phx-submit="save">
        <section class="space-y-1 rounded-box bg-base-100 p-4">
          <.movement_select field={@form[:movement_id]} movements={@movements} />
          <.input field={@form[:planned_on]} type="date" label="Date" />
          <.metric_inputs form={@form} />
        </section>
        <button
          id="save-planned-set"
          type="submit"
          class="btn btn-primary btn-lg mt-4 w-full"
          phx-disable-with="Saving…"
        >
          Save
        </button>
      </.form>
    </Layouts.app>
    """
  end
end
