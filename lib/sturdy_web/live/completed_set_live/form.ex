defmodule SturdyWeb.CompletedSetLive.Form do
  @moduledoc """
  Logs unplanned work (`:new`) or edits any completed set (`:edit`). Times are
  entered in local time. A completed plan keeps its plan's movement and side.
  """

  use SturdyWeb, :live_view

  import SturdyWeb.SetComponents

  alias Sturdy.Catalog
  alias Sturdy.LocalTime
  alias Sturdy.Training
  alias Sturdy.Training.CompletedSet
  alias SturdyWeb.DateParam
  alias SturdyWeb.LocalDateTimeInput

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(movements: Catalog.list_movements())
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    # Today defaults to now; another day defaults to its local noon.
    default_time = fn date ->
      if date == LocalTime.today(),
        do: DateTime.utc_now(:second),
        else: date |> NaiveDateTime.new!(~T[12:00:00]) |> LocalTime.from_local()
    end

    case DateParam.fetch(params) do
      {:ok, date} ->
        completed_set = %CompletedSet{completed_at: default_time.(date)}

        socket
        |> assign(page_title: "Log set", back: ~p"/days/#{date}", completed_set: completed_set)
        |> assign_form(
          Training.change_completed_set(completed_set, Map.take(params, ["movement_id"]))
        )

      :error ->
        socket |> put_flash(:error, "That isn't a date.") |> push_navigate(to: ~p"/")
    end
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    completed_set = Training.get_completed_set!(id)

    socket
    |> assign(
      page_title: "Edit set",
      back: ~p"/days/#{Training.day_of(completed_set)}",
      completed_set: completed_set
    )
    |> assign_form(Training.change_completed_set(completed_set))
  end

  @impl true
  def handle_event("validate", %{"completed_set" => params}, socket) do
    changeset = Training.change_completed_set(socket.assigns.completed_set, utc(params))
    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  def handle_event("save", %{"completed_set" => params}, socket) do
    case Training.save_completed_set(socket.assigns.completed_set, utc(params)) do
      {:ok, completed_set} ->
        completed_set = Training.get_completed_set!(completed_set.id)

        {:noreply,
         socket
         |> put_flash(:info, "Set saved.")
         |> push_navigate(to: ~p"/days/#{Training.day_of(completed_set)}")}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp utc(params), do: LocalDateTimeInput.put_utc(params, "completed_at")

  # The changeset's own action decides whether errors show.
  defp assign_form(socket, changeset) do
    assign(socket,
      form: to_form(changeset),
      editable: CompletedSet.editable_fields(socket.assigns.completed_set)
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} title={@page_title} tab={:day} back={@back}>
      <.form for={@form} id="completed-set-form" phx-change="validate" phx-submit="save">
        <section class="space-y-1 rounded-box bg-base-100 p-4">
          <.movement_select
            :if={:movement_id in @editable}
            field={@form[:movement_id]}
            movements={@movements}
          />
          <p :if={:movement_id not in @editable} id="planned-movement" class="mb-2">
            <.movement_link movement={@completed_set.movement} />
            <span class="text-sm text-base-content/60">
              {SturdyWeb.SetFormat.side(@completed_set.side)} · completes a plan
            </span>
          </p>
          <.input
            field={@form[:completed_at]}
            type="datetime-local"
            label="When"
            value={LocalDateTimeInput.to_input(@form[:completed_at].value)}
          />
          <.metric_inputs form={@form} side={:side in @editable} />
        </section>
        <button
          id="save-completed-set"
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
