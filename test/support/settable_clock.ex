defmodule Sturdy.SettableClock do
  @moduledoc """
  A clock tests can set. Unset, it tells the real time, so tests that don't
  care about time are unaffected.

  The setting is global to the VM (LiveView and web server processes must see
  it too), so tests that set it cannot run async.
  """

  @behaviour Sturdy.Clock

  @impl Sturdy.Clock
  @spec utc_now() :: DateTime.t()
  def utc_now, do: Application.get_env(:sturdy, __MODULE__) || DateTime.utc_now()

  @spec set(DateTime.t()) :: :ok
  def set(%DateTime{} = utc_now), do: Application.put_env(:sturdy, __MODULE__, utc_now)

  @spec reset() :: :ok
  def reset, do: Application.delete_env(:sturdy, __MODULE__)
end
