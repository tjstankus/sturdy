defmodule Sturdy.Acceptance.DSL do
  @moduledoc """
  LAYER 2 — the language executable specifications are written in.

  Every step takes the session first and returns it, so a spec reads as one
  pipeline. Steps translate spec phrasing into driver calls: they resolve date
  words against the (controllable) clock, apply defaults, rename spec words to
  domain fields, pick which entry an action targets, and compare what the
  driver read with what the spec expects.

  Nothing here knows about LiveView, browsers, DOM ids, routes, or the
  database. Only `Sturdy.Acceptance.Driver` callbacks are called.

  ## Set measurements

  Steps that describe a set accept `reps:`, `hold:` (seconds), `distance:`
  (meters), `load:` (pounds; 0 is bodyweight), `side:` (`:left`/`:right`),
  and `notes:`.
  """

  import ExUnit.Assertions

  alias Sturdy.Acceptance.Session
  alias Sturdy.Acceptance.Words
  alias Sturdy.LocalTime
  alias Sturdy.SettableClock

  @type s :: Session.t()

  # Spec words for measurements → the domain's field names.
  @measures %{
    reps: :reps,
    hold: :duration_s,
    distance: :distance_m,
    load: :weight_lb,
    side: :side,
    notes: :notes
  }

  ## Givens

  @doc ~S|Sets the local wall-clock time, e.g. `given_it_is("2026-11-10 08:00")`.|
  @spec given_it_is(s(), String.t()) :: s()
  def given_it_is(s, local) do
    local
    |> Words.local_datetime(LocalTime.today())
    |> LocalTime.from_local()
    |> SettableClock.set()

    s
  end

  @doc ~S|A tag category and its tags: `given_tags("muscle", ["pecs", "quads"])`.|
  @spec given_tags(s(), String.t(), [String.t()]) :: s()
  def given_tags(s, category, tags) do
    :ok = Session.call(s, :create_tag_category, [category])
    Enum.each(tags, &(:ok = Session.call(s, :create_tag, [category, &1])))
    s
  end

  @doc "A movement exists. Options: `notes:`, `tags:` (names), `videos:` ({label, url})."
  @spec given_movement(s(), String.t(), keyword()) :: s()
  def given_movement(s, name, opts \\ []) do
    assert Session.call(s, :create_movement, [movement(name, opts)]) == :ok,
           "expected movement #{inspect(name)} to be created"

    s
  end

  ## Actions

  @doc "Same as `given_movement/3`; reads better as the action under test."
  @spec add_movement(s(), String.t(), keyword()) :: s()
  def add_movement(s, name, opts \\ []), do: given_movement(s, name, opts)

  @doc """
  Plans sets of a movement. Options: `sets:` (default 1), `each_side: true`,
  `on:` a date word or a list of them (default `"today"`), plus measurements.
  """
  @spec plan(s(), String.t(), keyword()) :: s()
  def plan(s, movement, opts) do
    dates = opts |> Keyword.get(:on, "today") |> List.wrap() |> Enum.map(&date/1)
    schedule(s, movement, opts, %{dates: dates, range_from: nil, range_to: nil})
  end

  @doc "Plans sets on every day `from:` … `to:` (inclusive). Otherwise as `plan/3`."
  @spec plan_every_day(s(), String.t(), keyword()) :: s()
  def plan_every_day(s, movement, opts) do
    range = %{
      dates: [],
      range_from: opts |> Keyword.fetch!(:from) |> date(),
      range_to: opts |> Keyword.fetch!(:to) |> date()
    }

    schedule(s, movement, opts, range)
  end

  @doc "Marks a pending planned set done. Options: `on:` (default today), `side:`."
  @spec mark_done(s(), String.t(), keyword()) :: s()
  def mark_done(s, movement, opts \\ []), do: act(s, movement, :pending, :mark_done, opts)

  @doc "Skips a pending planned set."
  @spec skip(s(), String.t(), keyword()) :: s()
  def skip(s, movement, opts \\ []), do: act(s, movement, :pending, :skip, opts)

  @doc "Undoes a done planned set, returning it to pending."
  @spec undo(s(), String.t(), keyword()) :: s()
  def undo(s, movement, opts \\ []), do: act(s, movement, :done, :undo, opts)

  @doc "Deletes a logged (unplanned) set."
  @spec delete_logged(s(), String.t(), keyword()) :: s()
  def delete_logged(s, movement, opts \\ []), do: act(s, movement, :done, :delete, opts)

  @doc ~S|Changes a pending plan's measurements, e.g. `change_plan(s, "Squat", reps: 8)`.|
  @spec change_plan(s(), String.t(), keyword()) :: s()
  def change_plan(s, movement, opts) do
    edit(s, movement, :pending, measures(opts), opts)
  end

  @doc ~S|Moves a pending plan to another day: `reschedule(s, "Squat", to: "tomorrow")`.|
  @spec reschedule(s(), String.t(), keyword()) :: s()
  def reschedule(s, movement, opts) do
    edit(s, movement, :pending, %{planned_on: opts |> Keyword.fetch!(:to) |> date()}, opts)
  end

  @doc "Corrects a done set to what really happened (measurements and/or `at:`)."
  @spec record_actual(s(), String.t(), keyword()) :: s()
  def record_actual(s, movement, opts) do
    {_on, fields} = when_done(opts)
    edit(s, movement, :done, Map.merge(measures(opts), fields), opts)
  end

  @doc """
  Logs unplanned work. `at:` a local date-time (default: now, on today's
  log), plus measurements.
  """
  @spec log(s(), String.t(), keyword()) :: s()
  def log(s, movement, opts) do
    {on, fields} = when_done(opts)
    fields = opts |> measures() |> Map.merge(fields) |> Map.put(:movement, movement)
    :ok = Session.call(s, :log_set, [on, fields])
    s
  end

  ## Expectations

  @doc ~S|Counts a movement's entries on a day: `expect_day(s, "Squat", done: 1, pending: 2)`.|
  @spec expect_day(s(), String.t(), keyword()) :: s()
  def expect_day(s, movement, opts) do
    {on, counts} = Keyword.pop(opts, :on, "today")

    actual =
      s
      |> entries(date(on), movement)
      |> Enum.frequencies_by(& &1.state)

    zero = %{done: 0, pending: 0, skipped: 0}
    assert Map.merge(zero, actual) == Map.merge(zero, Map.new(counts))
    s
  end

  @doc """
  A movement's entries on a day, in order, as `state: summary` pairs:
  `expect_entries(s, "Plank", pending: "30s L", pending: "30s R")`.
  """
  @spec expect_entries(s(), String.t(), keyword(String.t()), keyword()) :: s()
  def expect_entries(s, movement, expected, opts \\ []) do
    actual =
      s
      |> entries(day(opts), movement)
      |> Enum.map(&{&1.state, Words.summary(&1.summary)})

    assert actual ==
             Enum.map(expected, fn {state, summary} -> {state, Words.summary(summary)} end)

    s
  end

  @doc """
  Details of a movement's first done entry: `summary:`, `at:` (local time),
  `planned:` (the plan's summary), `unplanned:` (boolean). Options `on:`, `side:`.
  """
  @spec expect_done(s(), String.t(), keyword()) :: s()
  def expect_done(s, movement, details) do
    {opts, details} = Keyword.split(details, [:on, :side])
    entry = find_entry!(s, movement, :done, opts)

    actual = %{
      summary: Words.summary(entry.summary),
      planned: Words.summary(entry.planned),
      at: entry.time,
      unplanned: is_nil(entry.planned)
    }

    normalize = %{
      summary: &Words.summary/1,
      planned: &Words.summary/1,
      at: &Words.time/1,
      unplanned: & &1
    }

    expected = Map.new(details, fn {key, value} -> {key, Map.fetch!(normalize, key).(value)} end)
    assert Map.take(actual, Map.keys(expected)) == expected
    s
  end

  @doc """
  What can be done to a movement's first entry in `state`:
  `expect_actions(s, "Squat", :skipped, [:delete])`. Actions: `:mark_done`,
  `:edit`, `:skip`, `:delete`, `:undo`.
  """
  @spec expect_actions(s(), String.t(), atom(), [atom()], keyword()) :: s()
  def expect_actions(s, movement, state, actions, opts \\ []) do
    assert Enum.sort(find_entry!(s, movement, state, opts).actions) == Enum.sort(actions)
    s
  end

  @spec expect_nothing_on(s(), String.t()) :: s()
  def expect_nothing_on(s, day) do
    assert Session.call(s, :read_day, [date(day)]) == []
    s
  end

  @doc "Every movement, alphabetically."
  @spec expect_movements(s(), [String.t()]) :: s()
  def expect_movements(s, names) do
    assert Session.call(s, :read_movements, []) == names
    s
  end

  @spec expect_movements_tagged(s(), String.t(), [String.t()]) :: s()
  def expect_movements_tagged(s, tag, names) do
    assert Session.call(s, :read_movements_tagged, [tag]) == names
    s
  end

  @doc """
  A movement's page: `notes:`, `tags:` (`"category: tag"`), `videos:` ({label, url}).
  """
  @spec expect_movement(s(), String.t(), keyword()) :: s()
  def expect_movement(s, name, details) do
    # Tags are a set; the page may list them in any order.
    normalize = %{notes: & &1, tags: &Enum.sort/1, videos: & &1}
    page = Session.call(s, :read_movement, [name])
    page = %{page | videos: Enum.map(page.videos, &{&1.label, &1.url})}

    expected =
      Map.new(details, fn {key, value} -> {key, Map.fetch!(normalize, key).(value)} end)

    actual = Map.new(expected, fn {key, _value} -> {key, normalize[key].(page[key])} end)
    assert actual == expected
    s
  end

  @spec expect_movement_rejected(s(), String.t(), keyword()) :: s()
  def expect_movement_rejected(s, name, opts \\ []) do
    assert Session.call(s, :create_movement, [movement(name, opts)]) == :rejected
    s
  end

  ## Translation

  defp movement(name, opts) do
    %{
      name: name,
      notes: opts[:notes],
      tags: Keyword.get(opts, :tags, []),
      videos:
        opts
        |> Keyword.get(:videos, [])
        |> Enum.map(fn {label, url} -> %{label: label, url: url} end)
    }
  end

  defp schedule(s, movement, opts, dates) do
    plan =
      Map.merge(dates, %{
        set: opts |> measures() |> Map.put(:movement, movement),
        copies: Keyword.get(opts, :sets, 1),
        per_side: Keyword.get(opts, :each_side, false)
      })

    :ok = Session.call(s, :plan_sets, [plan])
    s
  end

  defp act(s, movement, state, action, opts) do
    entry = find_entry!(s, movement, state, opts)
    :ok = Session.call(s, :act, [day(opts), entry.ref, action])
    s
  end

  defp edit(s, movement, state, fields, opts) do
    entry = find_entry!(s, movement, state, opts)
    :ok = Session.call(s, :edit, [day(opts), entry.ref, fields])
    s
  end

  # The page a done set is recorded on, and its time when the spec gives one.
  defp when_done(opts) do
    at = fn
      nil ->
        {LocalTime.today(), %{}}

      local ->
        at = Words.local_datetime(local, LocalTime.today())
        {NaiveDateTime.to_date(at), %{completed_at: at}}
    end

    at.(opts[:at])
  end

  defp measures(opts) do
    opts
    |> Keyword.take(Map.keys(@measures))
    |> Map.new(fn {word, value} -> {Map.fetch!(@measures, word), value} end)
  end

  # The first entry of a movement in the given state (optionally on a `side:`).
  defp find_entry!(s, movement, state, opts) do
    side_matches = fn
      :any, _side -> true
      wanted, side -> wanted == side
    end

    side = Keyword.get(opts, :side, :any)

    s
    |> entries(day(opts), movement)
    |> Enum.find(&(&1.state == state and side_matches.(side, &1.side))) ||
      flunk("no #{state} #{movement} entry (side: #{inspect(side)}) on #{day(opts)}")
  end

  defp entries(s, on, movement) do
    s
    |> Session.call(:read_day, [on])
    |> Enum.find(%{entries: []}, &(&1.movement == movement))
    |> Map.fetch!(:entries)
  end

  defp day(opts), do: opts |> Keyword.get(:on, "today") |> date()

  defp date(words), do: Words.date(words, LocalTime.today())
end
