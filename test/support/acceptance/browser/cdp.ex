defmodule Sturdy.Acceptance.Browser.CDP do
  @moduledoc """
  A minimal Chrome DevTools Protocol client: no chromedriver, no WebSocket.

  Chrome started with `--remote-debugging-pipe` reads CDP commands on file
  descriptor 3 and writes replies and events on descriptor 4; each message is
  JSON terminated by a NUL byte. An Erlang port gives us the child's stdin and
  stdout, so a tiny shell wrapper moves them onto 3 and 4 and `exec`s Chrome.

  Commands are matched to replies by `id`. Events are ignored: callers poll
  the page instead (see `Sturdy.Acceptance.Browser.Page`).

  Set `CHROME_PATH` to use a browser other than the default Google Chrome.
  """

  use GenServer

  @default_chrome "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
  @call_timeout 15_000

  @type t :: GenServer.server()
  @type session_id :: String.t() | nil

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts)

  @doc "Sends one CDP command, optionally to an attached target session."
  @spec command(t(), String.t(), map(), session_id()) :: {:ok, map()} | {:error, map()}
  def command(cdp, method, params \\ %{}, session_id \\ nil),
    do: GenServer.call(cdp, {:command, method, params, session_id}, @call_timeout)

  @impl true
  def init(_opts) do
    Process.flag(:trap_exit, true)
    chrome = System.get_env("CHROME_PATH", @default_chrome)

    File.exists?(chrome) ||
      raise "Chrome not found at #{inspect(chrome)}; set CHROME_PATH to a Chrome or Chromium binary"

    profile = Path.join(System.tmp_dir!(), "sturdy-chrome-#{System.unique_integer([:positive])}")

    # $0 is Chrome, $1 the profile; fd 3 ← our stdin, fd 4 → our stdout.
    script =
      ~s(exec "$0" --headless=new --disable-gpu --no-first-run --no-default-browser-check ) <>
        ~s(--user-data-dir="$1" --remote-debugging-pipe about:blank ) <>
        ~s(3<&0 4>&1 0</dev/null 1>/dev/null 2>/dev/null)

    port =
      Port.open({:spawn_executable, "/bin/sh"}, [
        :binary,
        :exit_status,
        args: ["-c", script, chrome, profile]
      ])

    {:ok, %{port: port, profile: profile, buffer: "", next_id: 1, waiting: %{}}}
  end

  @impl true
  def handle_call({:command, method, params, session_id}, from, state) do
    addressed = fn
      message, nil -> message
      message, session_id -> Map.put(message, :sessionId, session_id)
    end

    message = addressed.(%{id: state.next_id, method: method, params: params}, session_id)

    Port.command(state.port, [Jason.encode!(message), 0])

    {:noreply,
     %{state | next_id: state.next_id + 1, waiting: Map.put(state.waiting, state.next_id, from)}}
  end

  @impl true
  def handle_info({port, {:data, data}}, %{port: port} = state) do
    {complete, [rest]} = (state.buffer <> data) |> String.split(<<0>>) |> Enum.split(-1)

    answer = fn waiting, id, outcome ->
      {from, waiting} = Map.pop(waiting, id)
      GenServer.reply(from, outcome)
      waiting
    end

    reply = fn
      %{"id" => id, "result" => result}, waiting -> answer.(waiting, id, {:ok, result})
      %{"id" => id, "error" => error}, waiting -> answer.(waiting, id, {:error, error})
      _event, waiting -> waiting
    end

    waiting = complete |> Enum.map(&Jason.decode!/1) |> Enum.reduce(state.waiting, reply)
    {:noreply, %{state | buffer: rest, waiting: waiting}}
  end

  def handle_info({port, {:exit_status, status}}, %{port: port} = state),
    do: {:stop, {:chrome_exited, status}, state}

  def handle_info({:EXIT, _from, reason}, state), do: {:stop, reason, state}

  @impl true
  def terminate(_reason, state) do
    # Closing the pipe tells Chrome to quit.
    Port.close(state.port)
    File.rm_rf(state.profile)
  catch
    :error, :badarg -> File.rm_rf(state.profile)
  end
end
