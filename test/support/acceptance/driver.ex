defmodule Sturdy.Acceptance.Driver do
  @moduledoc """
  LAYER 3 — the contract every protocol driver fulfils.

  The DSL (layer 2) calls only these callbacks, so a spec runs unchanged
  against any driver. Callbacks speak the problem domain with concrete values
  (dates, local times, movement names); each driver decides *how* to perform
  them through its own channel to the system.

  Actions return `:ok` (or an outcome); reads return what the screen shows,
  already translated into the types below. A driver raises when the system
  refuses something a spec did not expect to be refused.
  """

  @typedoc "Whatever a driver needs between calls (a conn, a browser page)."
  @type state :: term()

  @type side :: :left | :right | nil
  @type entry_state :: :pending | :done | :skipped
  @type action :: :mark_done | :edit | :skip | :delete | :undo

  @typedoc """
  Set fields by their domain names: `:movement` (a movement name), `:side`,
  `:reps`, `:duration_s`, `:distance_m`, `:weight_lb`, `:notes`, and when
  editing or logging, `:planned_on` (a date) or `:completed_at` (a local
  `NaiveDateTime`). Only the fields present are filled in.
  """
  @type fields :: %{optional(atom()) => term()}

  @type plan :: %{
          set: fields(),
          copies: pos_integer(),
          per_side: boolean(),
          dates: [Date.t()],
          range_from: Date.t() | nil,
          range_to: Date.t() | nil
        }

  @type video :: %{label: String.t() | nil, url: String.t()}

  @type movement :: %{
          name: String.t(),
          notes: String.t() | nil,
          tags: [String.t()],
          videos: [video()]
        }

  @typedoc "A movement's page, as read back. Tags read as `\"category: tag\"`."
  @type movement_page :: %{notes: String.t() | nil, tags: [String.t()], videos: [video()]}

  @typedoc "One line of a day. `ref` is opaque: hand it back to `act/4` or `edit/4`."
  @type entry :: %{
          ref: String.t(),
          state: entry_state(),
          side: side(),
          summary: String.t(),
          planned: String.t() | nil,
          time: Time.t() | nil,
          actions: [action()]
        }

  @type group :: %{movement: String.t(), entries: [entry()]}

  @callback start() :: state()
  @callback stop(state()) :: :ok

  @callback create_tag_category(state(), name :: String.t()) :: :ok
  @callback create_tag(state(), category :: String.t(), name :: String.t()) :: :ok
  @callback create_movement(state(), movement()) :: :ok | :rejected

  @callback plan_sets(state(), plan()) :: :ok
  @callback log_set(state(), on :: Date.t(), fields()) :: :ok
  @callback act(state(), on :: Date.t(), ref :: String.t(), action()) :: :ok
  @callback edit(state(), on :: Date.t(), ref :: String.t(), fields()) :: :ok

  @callback read_day(state(), Date.t()) :: [group()]
  @callback read_movements(state()) :: [String.t()]
  @callback read_movements_tagged(state(), tag :: String.t()) :: [String.t()]
  @callback read_movement(state(), name :: String.t()) :: movement_page()
end
