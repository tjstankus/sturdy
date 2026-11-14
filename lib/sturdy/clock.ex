defmodule Sturdy.Clock do
  @moduledoc """
  The app's single source of the current time, to the second.

  Which clock is used comes from `config :sturdy, :clock`. Production uses
  `Sturdy.Clock.System`; tests can configure a clock they control, so behaviour
  that depends on "now" (today's date, a default log time) can be specified.
  """

  @doc "The current instant in UTC."
  @callback utc_now() :: DateTime.t()

  @spec utc_now() :: DateTime.t()
  def utc_now do
    clock = Application.fetch_env!(:sturdy, :clock)
    DateTime.truncate(clock.utc_now(), :second)
  end
end
