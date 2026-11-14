defmodule Sturdy.Acceptance.Session do
  @moduledoc """
  What a spec pipes from step to step: which driver is running, and its state.
  Specs never look inside; the DSL does.
  """

  alias Sturdy.Acceptance.Driver

  @enforce_keys [:driver, :state]
  defstruct [:driver, :state]

  @type t :: %__MODULE__{driver: module(), state: Driver.state()}

  @spec new(module()) :: t()
  def new(driver), do: %__MODULE__{driver: driver, state: driver.start()}

  @doc "Calls a driver callback with the session's state as the first argument."
  @spec call(t(), atom(), [term()]) :: term()
  def call(%__MODULE__{driver: driver, state: state}, callback, args),
    do: apply(driver, callback, [state | args])

  @spec stop(t()) :: :ok
  def stop(%__MODULE__{} = session), do: call(session, :stop, [])
end
