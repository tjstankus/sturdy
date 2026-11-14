defmodule Sturdy.AcceptanceCase do
  @moduledoc """
  The case template for executable specifications (`test/acceptance/specs`).

  Each spec module runs once per protocol driver (ExUnit parameterization),
  so every test is reported per driver. Choose drivers with `STURDY_DRIVER`,
  a comma-separated list of `live_view` and `browser` (default: both).

  Specs are `async: false`: the clock is global to the VM, and the browser
  driver's server processes share the test's database connection through the
  sandbox's shared mode.

  The test context carries `:sturdy`, the session every DSL step takes.
  """

  alias Sturdy.Acceptance.Drivers.BrowserDriver
  alias Sturdy.Acceptance.Drivers.LiveViewDriver
  alias Sturdy.Acceptance.Session

  @drivers %{"live_view" => LiveViewDriver, "browser" => BrowserDriver}

  defmacro __using__(_opts) do
    quote do
      use ExUnit.Case, async: false, parameterize: Sturdy.AcceptanceCase.drivers()

      import Sturdy.Acceptance.DSL

      @moduletag :acceptance

      setup context, do: Sturdy.AcceptanceCase.start_session(context)
    end
  end

  @doc "The drivers to run, as ExUnit parameters."
  @spec drivers() :: [%{driver: module()}]
  def drivers do
    "STURDY_DRIVER"
    |> System.get_env(Enum.join(Map.keys(@drivers), ","))
    |> String.split(",", trim: true)
    |> Enum.map(&%{driver: Map.fetch!(@drivers, &1)})
  end

  @doc false
  @spec start_session(map()) :: %{sturdy: Session.t()}
  def start_session(%{driver: driver} = context) do
    # on_exit callbacks run last-registered first: the driver stops before
    # the clock resets and the sandbox owner (registered first) goes away.
    Sturdy.DataCase.setup_sandbox(context)
    ExUnit.Callbacks.on_exit(&Sturdy.SettableClock.reset/0)
    session = Session.new(driver)
    ExUnit.Callbacks.on_exit(fn -> Session.stop(session) end)
    %{sturdy: session}
  end
end
