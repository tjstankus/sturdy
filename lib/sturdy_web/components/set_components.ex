defmodule SturdyWeb.SetComponents do
  @moduledoc """
  Form inputs and display pieces shared by the planned- and completed-set screens.
  """

  use SturdyWeb, :html

  alias Sturdy.Catalog.Movement

  @doc "A movement picker."
  attr :field, Phoenix.HTML.FormField, required: true
  attr :movements, :list, required: true

  def movement_select(assigns) do
    assigns = assign(assigns, :options, Enum.map(assigns.movements, &{&1.name, &1.id}))

    ~H"""
    <.input
      field={@field}
      type="select"
      label="Movement"
      prompt="Choose a movement"
      options={@options}
    />
    """
  end

  @doc """
  Measurement inputs: side, reps, duration, distance, load, notes. Numeric
  inputs raise the phone's number pad.
  """
  attr :form, Phoenix.HTML.Form, required: true
  attr :side, :boolean, default: true, doc: "whether side is editable here"

  def metric_inputs(assigns) do
    ~H"""
    <.input
      :if={@side}
      field={@form[:side]}
      type="select"
      label="Side"
      options={[{"Both / bilateral", ""}, {"Left", "left"}, {"Right", "right"}]}
    />
    <div class="grid grid-cols-2 gap-x-3">
      <.input field={@form[:reps]} type="number" label="Reps" min="1" inputmode="numeric" />
      <.input
        field={@form[:duration_s]}
        type="number"
        label="Hold (seconds)"
        min="1"
        inputmode="numeric"
      />
      <.input
        field={@form[:distance_m]}
        type="number"
        label="Distance (m)"
        min="1"
        inputmode="numeric"
      />
      <.input
        field={@form[:weight_lb]}
        type="number"
        label="Load (lb)"
        step="0.5"
        inputmode="decimal"
        placeholder="0 = bodyweight"
      />
    </div>
    <p class="-mt-1 mb-2 text-xs text-base-content/60">
      Load is external weight: 0 for bodyweight, negative for assistance.
    </p>
    <.input field={@form[:notes]} type="textarea" label="Notes" rows="2" />
    """
  end

  @doc "A movement name linking to its page."
  attr :movement, Movement, required: true
  attr :class, :any, default: nil

  def movement_link(assigns) do
    ~H"""
    <.link navigate={~p"/movements/#{@movement}"} class={["font-semibold hover:underline", @class]}>
      {@movement.name}
    </.link>
    """
  end
end
