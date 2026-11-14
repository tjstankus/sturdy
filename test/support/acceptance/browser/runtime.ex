defmodule Sturdy.Acceptance.Browser.Runtime do
  @moduledoc """
  What the browser driver shares across a whole test run: one HTTP server
  for the app and one Chrome. Started on first use and stopped after the
  suite, so runs that skip the browser driver never pay for it.

  The server is the real endpoint, served by Bandit on a free loopback port.
  It needs no sandbox plumbing: specs use the sandbox's shared mode, so its
  request and LiveView processes use the running spec's connection.
  """

  use GenServer

  alias Sturdy.Acceptance.Browser.CDP

  @type info :: %{base_url: String.t(), cdp: CDP.t()}

  @doc "Starts the server and browser if needed; returns how to reach them."
  @spec ensure_started() :: info()
  def ensure_started do
    running = fn
      {:ok, pid} -> pid
      {:error, {:already_started, pid}} -> pid
    end

    # Unlinked: it must outlive the test process that happens to start it.
    __MODULE__
    |> GenServer.start(:ok, name: __MODULE__)
    |> running.()
    |> GenServer.call(:info)
  end

  @impl true
  def init(:ok) do
    {:ok, server} =
      Bandit.start_link(plug: SturdyWeb.Endpoint, ip: :loopback, port: 0, startup_log: false)

    {:ok, {_ip, port}} = ThousandIsland.listener_info(server)
    {:ok, cdp} = CDP.start_link()
    ExUnit.after_suite(fn _results -> GenServer.stop(__MODULE__) end)

    {:ok, %{server: server, info: %{base_url: "http://localhost:#{port}", cdp: cdp}}}
  end

  @impl true
  def handle_call(:info, _from, state), do: {:reply, state.info, state}

  @impl true
  def terminate(_reason, state) do
    GenServer.stop(state.info.cdp)
    Supervisor.stop(state.server)
  end
end
