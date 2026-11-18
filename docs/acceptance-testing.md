# Acceptance testing in Sturdy

This document explains how Sturdy's acceptance tests are built and why,
in enough detail to rebuild the approach in another project.

It complements `test/acceptance/README.md`, the quick reference that sits
next to the tests (commands, where things live, how to add a spec). This
document is the longer version: the goals, the design of each layer, how one
spec step travels through the system, the problems that came up along the
way, and the trade-offs that are still open.

## Contents

1. [Goals](#1-goals)
2. [The shape: four layers](#2-the-shape-four-layers)
3. [One step, end to end](#3-one-step-end-to-end)
4. [Layer 1: executable specifications](#4-layer-1-executable-specifications)
5. [Layer 2: the DSL](#5-layer-2-the-dsl)
6. [Layer 3: protocol drivers](#6-layer-3-protocol-drivers)
7. [The browser driver's plumbing](#7-the-browser-drivers-plumbing)
8. [Isolation and time](#8-isolation-and-time)
9. [The pipeline stage](#9-the-pipeline-stage)
10. [Held-back specs](#10-held-back-specs)
11. [Evidence that it works](#11-evidence-that-it-works)
12. [Pitfalls we hit](#12-pitfalls-we-hit)
13. [Trade-offs and open questions](#13-trade-offs-and-open-questions)
14. [Copying this into another project](#14-copying-this-into-another-project)

---

## 1. Goals

The approach follows Dave Farley's acceptance-test-driven development, as
described in *Continuous Delivery* and *Modern Software Engineering* and in
his talks on acceptance testing. The specific goals for Sturdy were:

- **Specs say what, never how.** A spec reads as a statement about the
  problem domain (planning sets, marking them done, logging unplanned work).
  It doesn't mention pages, DOM ids, forms, or the database.
- **One spec, many channels.** The same spec runs against the system through
  more than one protocol driver. Sturdy has two: an in-process LiveView
  driver and a real headless browser. Every spec runs on both.
- **An internal DSL in plain ExUnit.** No Gherkin and no step-definition
  matching: specs are ordinary Elixir functions piped together.
- **Custom tooling.** No acceptance-testing libraries. The browser driver
  talks to Chrome directly over the DevTools Protocol, so there's no
  chromedriver, Node, Playwright, or WebSocket client. Every line is ours
  to read and understand.
- **Real isolation, controllable time.** Each spec starts from an empty
  database (Ecto's sandbox, nothing else), and time is something a spec can
  set.
- **A separate pipeline stage.** `mix test` stays fast; the acceptance stage
  runs after it.
- **Specs owned by people.** Coding agents may change everything beneath the
  specs but never the specs themselves, and that rule is enforced.

The design also had to be easy to study and copy: someone less experienced
should be able to imitate the patterns and still get good results.

## 2. The shape: four layers

```
┌────────────────────────────────────────────────────────────────────┐
│ 1. Executable specifications      test/acceptance/specs/*.exs      │
│    "plan 3 sets of Push-up, mark one done, expect 1 done 2 pending"│
├────────────────────────────────────────────────────────────────────┤
│ 2. DSL                            test/support/acceptance/dsl.ex   │
│    date words, defaults, vocabulary, targeting, comparison         │
├────────────────────────────────────────────────────────────────────┤
│ 3. Protocol drivers               test/support/acceptance/         │
│    Driver (behaviour) ─┬─ LiveViewDriver   (Phoenix.LiveViewTest)  │
│                        └─ BrowserDriver    (Chrome over CDP)       │
│    WebUI: shared knowledge of the screens                          │
├────────────────────────────────────────────────────────────────────┤
│ 4. System under test              lib/ (router, LiveViews, Repo)   │
└────────────────────────────────────────────────────────────────────┘
```

**The dependency rule: each layer knows only the layer directly below it.**

- Specs call DSL functions and nothing else.
- The DSL calls `Sturdy.Acceptance.Driver` callbacks and nothing else. It
  doesn't know which driver is running.
- Drivers know the screens. They are the only code that knows about routes,
  selectors, form field names, or how to wait for a page.
- The system under test doesn't know it's being tested. The only
  concessions in `lib/` are a clock seam and some `data-*` attributes that
  describe the markup for machines (see [section 6](#the-data--attributes)).

That rule is what makes the suite cheap to keep. When the UI changes, the
driver layer changes, and the specs stay as they are.

### Where the files are

```
test/acceptance/
  README.md                       quick reference
  words_test.exs                  unit tests for date/time words
  specs/                          LAYER 1 (held back: people only)
    planning_spec_test.exs
    completing_spec_test.exs
    skipping_spec_test.exs
    logging_spec_test.exs
    movements_spec_test.exs
test/support/acceptance/
  acceptance_case.ex              case template: one run per driver
  session.ex                      the value piped through a spec
  dsl.ex                          LAYER 2
  words.ex                        LAYER 2: "tomorrow", "in 3 days", "08:00"
  driver.ex                       LAYER 3: the behaviour and its types
  web_ui.ex                       LAYER 3: shared screen knowledge
  drivers/live_view_driver.ex     LAYER 3
  drivers/browser_driver.ex       LAYER 3
  browser/cdp.ex                  Chrome DevTools Protocol client
  browser/page.ex                 one tab: visit, click, fill, wait
  browser/runtime.ex              the shared server and Chrome
lib/sturdy/clock.ex               the clock seam (production)
test/support/settable_clock.ex    the clock specs control
.claude/settings.json             the guard (deny rules + hook)
.claude/hooks/protect_specs.py    the hook, with its own tests
```

## 3. One step, end to end

Following a single step through every layer shows what each one does. Take
this spec from `completing_spec_test.exs`:

```elixir
test "marking a planned set done records it now, and the day shows progress", %{sturdy: s} do
  s
  |> plan("Push-up", sets: 3, reps: 12)
  |> given_it_is("2026-11-10 09:15")
  |> mark_done("Push-up")
  |> expect_day("Push-up", done: 1, pending: 2)
  |> expect_done("Push-up", summary: "12 reps", at: "09:15", unplanned: false)
end
```

Here is what happens to `mark_done("Push-up")`.

**Layer 1, the spec.** It says *mark the Push-up done*. It doesn't say which
day, which of the three sets, which button, or which page.

**Layer 2, the DSL** fills in what the spec left out:

```elixir
def mark_done(s, movement, opts \\ []), do: act(s, movement, :pending, :mark_done, opts)

defp act(s, movement, state, action, opts) do
  entry = find_entry!(s, movement, state, opts)
  :ok = Session.call(s, :act, [day(opts), entry.ref, action])
  s
end
```

- `day(opts)` defaults to `"today"` and resolves it against the controllable
  clock, giving `~D[2026-11-10]`.
- `find_entry!` asks the driver to read that day (`read_day/2`), then picks
  the first `:pending` Push-up entry. *Which* set gets marked is a domain
  rule ("the next one"), so it lives in the DSL, not in a driver.
- It hands the driver the entry's opaque `ref` and the action `:mark_done`.

**Layer 3, the driver** performs `act(state, ~D[2026-11-10], "planned-42", :mark_done)`
through its own channel. Both drivers use the same `WebUI` knowledge:

```elixir
WebUI.day_path(~D[2026-11-10])                # "/days/2026-11-10"
WebUI.entry_action("planned-42", :mark_done)  # ~s|#planned-42 [data-action="mark_done"]|
```

The LiveView driver mounts the page in-process and sends the click:

```elixir
{:ok, view, _html} = live(conn, WebUI.day_path(on))
view |> element(WebUI.entry_action(ref, action)) |> render_click()
```

The browser driver loads the page in Chrome, clicks the real button, and
waits for LiveView to finish:

```elixir
state |> visit(WebUI.day_path(on)) |> Page.click(WebUI.entry_action(ref, action))
```

**Layer 4, the system** runs the real `DayLive` event handler, which writes
a completed set through the real `Training` context into the real (sandboxed)
database, stamped with `Sturdy.Clock.utc_now()`, which the spec set to 09:15.

Next, **`expect_day`** asks the driver to `read_day` again. Each driver turns
the page into neutral data using the same reader, `WebUI.day/1`:

```elixir
[%{movement: "Push-up",
   entries: [%{ref: "…", state: :done, summary: "12 reps", time: ~T[09:15:00], …},
             %{ref: "…", state: :pending, …},
             %{ref: "…", state: :pending, …}]}]
```

The DSL counts states and compares them with `done: 1, pending: 2`.
Assertions live in the DSL; drivers only report what the screen shows.

## 4. Layer 1: executable specifications

### Style rules

- **Domain words only.** No ids, routes, HTML, Ecto, or driver names. If a
  spec needs a word the DSL doesn't have yet, the DSL grows, in domain terms.
- **One rule per test, named for the rule.** Test names are sentences a
  person who knows the domain would agree or disagree with:
  - "skipping is final: a skipped set can only be deleted"
  - "a plan done late still belongs to the day it was planned for"
  - "work just after midnight belongs to the new day"
- **Concrete times when time matters.** Specs that depend on "now" set it
  (`given_it_is("2026-11-10 23:15")`), so they're deterministic.
- **Setup is givens.** A `setup` block establishes the world in DSL terms:

  ```elixir
  setup %{sturdy: s} do
    s |> given_it_is("2026-11-10 08:00") |> given_movement("Squat")
    :ok
  end
  ```

- **One pipeline per test.** A `%Session{}` is piped through every step.
  Steps return the session, so givens, actions, and expectations chain
  freely, and an expectation can sit in the middle of a story:

  ```elixir
  s
  |> log("Push-up", reps: 15)
  |> expect_actions("Push-up", :done, [:edit, :delete])
  |> delete_logged("Push-up")
  |> expect_nothing_on("today")
  ```

### Why an internal DSL and not Gherkin

Farley prefers internal DSLs: they're ordinary code, so you get the
compiler, your editor's navigation, refactoring, and typespecs for free, and
there's no regex step-matching layer between the words and the code. The
pipe operator makes an Elixir spec read almost like prose without any
parsing.

### What the specs cover

22 specs, each run on two drivers (44 runs):

| File | Rules pinned down |
|---|---|
| `planning_spec_test.exs` | plans start pending; each side; chosen days; a range of days; changing a plan; rescheduling |
| `completing_spec_test.exs` | marking done records now; reality can differ from the plan; undo; a done plan can't be deleted; late completion stays on the planned day |
| `skipping_spec_test.exs` | skipping leaves the rest pending; skipping is final; what a pending set allows |
| `logging_spec_test.exs` | logs default to now; after midnight is the new day; late evening stays on its day; logged alongside planned; logged work can be deleted |
| `movements_spec_test.exs` | movements carry notes, tags, and videos; names are unique, ignoring case; listed alphabetically and filterable by tag |

## 5. Layer 2: the DSL

`Sturdy.Acceptance.DSL` is imported into every spec by the case template.
Every public step has an `@spec` and takes and returns `Session.t()`.

### The session

```elixir
defmodule Sturdy.Acceptance.Session do
  defstruct [:driver, :state]

  def new(driver), do: %__MODULE__{driver: driver, state: driver.start()}

  def call(%__MODULE__{driver: driver, state: state}, callback, args),
    do: apply(driver, callback, [state | args])
end
```

Specs never look inside the session. The DSL only ever reaches the system
through `Session.call/3`, so it can't depend on a particular driver.

### The DSL's five jobs

1. **Date and time words.** `Sturdy.Acceptance.Words` turns `"today"`,
   `"tomorrow"`, `"yesterday"`, `"in 3 days"`, `"2 days ago"`, ISO dates,
   and `"tomorrow 00:30"` into `Date`s and local `NaiveDateTime`s, relative
   to the clock's today. It's pure, so it has its own unit test
   (`test/acceptance/words_test.exs`).
2. **Defaults.** `sets: 1`, `on: "today"`. A spec mentions a value only when
   the rule depends on it.
3. **Vocabulary.** Spec words map to domain fields in one table:

   ```elixir
   @measures %{reps: :reps, hold: :duration_s, distance: :distance_m,
               load: :weight_lb, side: :side, notes: :notes}
   ```

4. **Targeting.** "Mark the Push-up done" means the first pending Push-up
   entry on that day, optionally narrowed with `side:`. Drivers never
   decide which entry a spec means.
5. **Comparison.** Drivers return neutral data; the DSL asserts on it.
   Comparison is forgiving about presentation and strict about meaning:
   summaries compare without separators (`"30s L"` matches `"30s · L"`),
   and a movement's tags compare as a set.

### Givens, actions, expectations

| Kind | Steps |
|---|---|
| Givens | `given_it_is`, `given_tags`, `given_movement` |
| Actions | `add_movement`, `plan`, `plan_every_day`, `mark_done`, `skip`, `undo`, `delete_logged`, `change_plan`, `reschedule`, `record_actual`, `log` |
| Expectations | `expect_day`, `expect_entries`, `expect_done`, `expect_actions`, `expect_nothing_on`, `expect_movements`, `expect_movements_tagged`, `expect_movement`, `expect_movement_rejected` |

Givens go through the drivers, the same as actions. `given_movement` creates
the movement through the UI, not by inserting rows. That's slower, but it
means a spec never depends on how data is stored, and every given is also a
test of the screen it uses.

The one exception is time. `given_it_is` sets `Sturdy.SettableClock`
directly, because there's no screen for "it is now 09:15", and every driver
runs the system in the same VM, so they all see the same clock.

## 6. Layer 3: protocol drivers

### The contract

`Sturdy.Acceptance.Driver` is a behaviour with typed callbacks in domain
terms:

```elixir
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
```

The design rules behind it:

- **Concrete values in, neutral data out.** The DSL has already resolved
  words into `Date`s and field names, so drivers never parse spec phrasing.
  Reads return plain maps (`entry`, `group`, `movement_page`), never HTML.
- **Opaque references.** An entry's `ref` comes from a read and goes back
  into `act/4` or `edit/4`. The DSL never looks at what it is (today it's a
  DOM id).
- **Expected refusals are outcomes; unexpected ones are errors.** The spec
  for duplicate movement names expects `:rejected`, so
  `create_movement` returns `:ok | :rejected`. Everywhere else, a refused
  form means a broken system or driver, so the driver raises with the
  form's error messages.
- **A few broad callbacks, not many narrow ones.** `act/4` covers mark done,
  skip, undo, and delete, because to a driver they're all "click this
  entry's button".

### WebUI: the screen knowledge both drivers share

Both drivers drive the same screens and differ only in how they reach them.
Everything about the screens lives in one module, `Sturdy.Acceptance.WebUI`:

| Kind | Examples |
|---|---|
| Paths | `day_path/1`, `plan_path/1`, `log_path/1`, `movements_path/0` |
| Landmarks: an element that proves a screen has arrived | `day_screen` (`#groups`), `movement_screen`, `edit_screen`, `refusal` (field errors or an error flash) |
| Selectors | `entry_action(ref, action)`, `movement_link(name)`, `tag_filter(html, tag)` |
| Form params, nested the way a browser submits them | `set_params/3`, `plan_params/2`, `movement_params/2` |
| Readers: rendered HTML to driver types | `day/1`, `movements/1`, `movement/1`, `errors/1` |

Without `WebUI`, each driver would have its own copy of every selector, and
a markup change would mean fixing both copies.

### The `data-*` attributes

Drivers read meaning from attributes, not from styling or visible text. The
day view renders:

```heex
<li id={"planned-#{@entry.planned_set.id}"} data-state="pending" data-side="left"
    data-summary="12 reps" ...>
  <button data-action="mark_done" ...>
```

The vocabulary is `data-state`, `data-side`, `data-summary`, `data-planned`,
`data-time`, `data-action`, and `data-movement`. This is the only test-driven
change to production markup. It's small and stable, and it means a
restyle or a copy change ("Done" → "Complete") doesn't break the suite.

### The LiveView driver

`Sturdy.Acceptance.Drivers.LiveViewDriver` uses `Phoenix.LiveViewTest`
in-process: the real router, LiveViews, and database, but no HTTP and no
JavaScript. It runs all 22 specs in about 1.5 seconds.

- **State is just a conn.** Every callback mounts a fresh page with
  `live(conn, path)`, so nothing carries over between steps.
- **Navigation shows success.** A saved form live-redirects away, so
  `{:error, {:live_redirect, _}}` means accepted and rendered HTML means the
  form stayed put and was refused.
- **Client behaviour is simulated.** Where the page depends on JavaScript,
  the driver sends the event the client would have sent. The "Add video"
  button is a client-side JS command, so the driver sends the `validate`
  change it would dispatch. `data-confirm` dialogs don't exist here at all.

That simulation is the reason to have a second driver.

### The browser driver

`Sturdy.Acceptance.Drivers.BrowserDriver` uses headless Chrome emulating a
390×844 phone, against the app served over real HTTP and websockets, with
LiveView's JavaScript client running. It's the most faithful driver and
takes about 12 seconds for all specs.

- **Same callbacks, same `WebUI`.** Most callbacks read almost the same as
  their LiveView counterparts:

  ```elixir
  def log_set(state, on, fields) do
    page = visit(state, WebUI.log_path(on))

    page
    |> Page.fill_form(WebUI.set_params(Page.html(page), "completed_set", fields))
    |> submit!(WebUI.log_form(), WebUI.day_screen())
  end
  ```

- **Landmarks show success.** After submitting, the driver waits for
  either the next screen's landmark or a refusal, whichever appears first,
  and maps it to `:ok` or `:rejected`.
- **One tab per spec.** The server and Chrome are shared by the whole run;
  each spec opens its own tab in `start/0` and closes it in `stop/1`.

## 7. The browser driver's plumbing

About 350 lines in three modules, with no dependencies beyond `jason` and
`bandit`, which the app already uses.

### `Browser.CDP`: talking to Chrome

Chrome started with `--remote-debugging-pipe` reads DevTools Protocol
commands on file descriptor 3 and writes replies and events on descriptor 4,
as JSON messages each terminated by a NUL byte. An Erlang port gives us a
child process's stdin and stdout, so a one-line shell wrapper moves them
onto 3 and 4 and `exec`s Chrome:

```elixir
script =
  ~s(exec "$0" --headless=new --disable-gpu --no-first-run --no-default-browser-check ) <>
    ~s(--user-data-dir="$1" --remote-debugging-pipe about:blank ) <>
    ~s(3<&0 4>&1 0</dev/null 1>/dev/null 2>/dev/null)

Port.open({:spawn_executable, "/bin/sh"}, [:binary, :exit_status, args: ["-c", script, chrome, profile]])
```

The GenServer numbers each command, remembers who's waiting for which `id`,
splits incoming data on NUL, and replies when the matching message arrives.
Events are ignored. Closing the port tells Chrome to quit, and `terminate/2`
removes the temporary profile. `CHROME_PATH` overrides the default macOS
Chrome location.

### `Browser.Page`: one tab

- `open/1` creates a target, attaches with `flatten: true` (so later
  commands carry a `sessionId`), and sets the phone viewport.
- Everything else is `Runtime.evaluate`: clicks are real `el.click()`
  calls, and filled fields dispatch `input` and `change` events so LiveView
  sees them as typing.
- `fill_form/2` takes the same nested params the LiveView driver passes to
  `form/3` and flattens them into field names (`%{"a" => %{"b" => 1}}` →
  `a[b]`), so both drivers share `WebUI`'s params.

### Waiting: the hard part

LiveView updates arrive asynchronously, so a browser driver that acts and
reads immediately will be flaky. `Page` waits in three ways:

1. **Settle.** After every click, fill, or submit, wait until the LiveView is
   connected and no loading class remains:

   ```javascript
   !!document.querySelector('[data-phx-main].phx-connected') &&
     !document.querySelector('.phx-click-loading, .phx-submit-loading, .phx-change-loading')
   ```

   LiveView adds those classes while an event is in flight and removes them
   when the server's reply has been applied, which is exactly "done".
2. **Landmarks.** A step that navigates waits for an element of the *next*
   screen, because the old screen settles too.
3. **A leaving marker.** Before a full page load, `visit/2` sets
   `window.__sturdyLeaving = true` and then waits for a document where it's
   absent. Otherwise the wait could succeed on the old, still-connected page
   before the navigation starts.

Waiting is polling: evaluate the condition every 20 ms, up to 5 seconds,
then fail with a message saying what it was waiting for. The browser can't
send an Erlang message when the page changes, so polling with
`Process.sleep/1` is the honest option here (see
[section 13](#13-trade-offs-and-open-questions)).

### `Browser.Runtime`: the shared server and Chrome

The first spec that uses the browser driver starts, in one named GenServer:

- **Bandit serving `SturdyWeb.Endpoint` as a plug** on a free loopback port
  (`port: 0`). It's the real endpoint, so the browser gets the real
  pipeline, but the test environment's endpoint config needs no
  `server: true`.
- **One Chrome**, via `CDP.start_link/0`.

The GenServer is started *unlinked* (it must outlive whichever test process
happened to start it) and stops itself through `ExUnit.after_suite/1`. A run
with only the LiveView driver never starts it.

## 8. Isolation and time

### The database

Each spec runs in an Ecto sandbox transaction that is rolled back
afterwards, with nothing else: no truncation and no per-test schemas.

The browser driver makes this harder, because the requests and LiveView
processes that touch the database aren't the test process. Rather than
plumbing sandbox metadata through a plug and the LiveView socket, specs use
the sandbox's **shared mode**: every process uses the test's connection.

Shared mode requires `async: false`, which the clock requires anyway (it's
global to the VM). The suite is fast enough serially.

The order of teardown matters. `on_exit` callbacks run last-registered
first, so `AcceptanceCase.start_session/1` registers them so that the driver
stops (closing the tab) before the clock resets and before the sandbox owner
goes away:

```elixir
Sturdy.DataCase.setup_sandbox(context)
ExUnit.Callbacks.on_exit(&Sturdy.SettableClock.reset/0)
session = Session.new(driver)
ExUnit.Callbacks.on_exit(fn -> Session.stop(session) end)
```

### Time

Production code never calls `DateTime.utc_now/0` directly. It asks
`Sturdy.Clock`:

```elixir
defmodule Sturdy.Clock do
  @callback utc_now() :: DateTime.t()

  def utc_now do
    clock = Application.fetch_env!(:sturdy, :clock)
    DateTime.truncate(clock.utc_now(), :second)
  end
end
```

`config/config.exs` selects `Sturdy.Clock.System`; `config/test.exs`
selects `Sturdy.SettableClock`, which **tells real time until a test sets
it** (so ordinary unit tests are unaffected) and is reset after every spec.

Because the browser's server runs in the same VM as the specs, setting the
clock affects both drivers equally. The midnight-boundary and late-evening
logging specs depend on this.

## 9. The pipeline stage

```
mix test                                # unit stage only
mix acceptance                          # every spec on every driver
STURDY_DRIVER=live_view mix acceptance  # just one driver (live_view | browser)
mix precommit                           # everything, in order
```

- **Tagging.** `use Sturdy.AcceptanceCase` adds `@moduletag :acceptance`,
  and `test/test_helper.exs` starts ExUnit with `exclude: [:acceptance]`.
- **Alias.** `acceptance: ["assets.build", "test --only acceptance"]`, with
  `acceptance: :test` in `preferred_envs`. Assets are built first so the
  browser driver always tests the current JavaScript.
- **One run per driver.** The case template uses ExUnit's parameterized
  tests:

  ```elixir
  use ExUnit.Case, async: false, parameterize: Sturdy.AcceptanceCase.drivers()
  ```

  `drivers/0` reads `STURDY_DRIVER` (a comma-separated list, defaulting to
  both). Each test is reported once per driver, with the driver in its name.
- **`mix precommit`** runs the commit stage first (compile with warnings as
  errors, unused-deps check, format, `credo --strict`, `coveralls` with a 95%
  floor) and then the acceptance stage via `cmd mix acceptance` (a separate
  OS process, so it gets a fresh VM in the test env), and finally the guard
  hook's own unit tests.

## 10. Held-back specs

Specs state what people want the system to do. If a coding agent could edit
them, the quickest way to green would be to change the spec, and the suite
would stop meaning anything. So in this repository the specs directory is
off-limits to agents, in three layers:

1. **`AGENTS.md`** says so at the top, where every agent reads it: never
   create, edit, move, or delete anything in `test/acceptance/specs/`; change
   the DSL, drivers, or production code instead; if a spec seems wrong,
   stop and ask.
2. **Claude Code deny rules** in `.claude/settings.json`:

   ```json
   "permissions": {
     "deny": ["Edit(/test/acceptance/specs/**)", "Edit(test/acceptance/specs/**)"]
   }
   ```

   Claude Code's file-path rules use `Edit` for every file-writing tool, and
   the two spellings cover both ways a path can be matched.
3. **A `PreToolUse` hook**, `.claude/hooks/protect_specs.py`, on `Bash` and
   every file tool:
   - File tools: refuse any target inside the directory, after resolving
     `..` and symlinks.
   - Shell commands that mention the specs: refuse any redirection or `tee`,
     then require every part of the command to be known read-only (`cat`,
     `grep`, `sed` without `-i`, `find` without `-delete`/`-exec`,
     `git diff`/`log`/`show`/`status`, `mix test`/`acceptance`, …). It's an
     allowlist: anything unrecognised is refused.
   - It has its own unit tests (`python3 -m unittest discover -s .claude/hooks`),
     which `mix precommit` runs.

Its limits are deliberate. It's a guardrail against an agent "fixing" a
spec to get green, not a security boundary. A command that never names the
directory (a path built at runtime, say) isn't caught, and plain `mix format`
still reformats specs (layout only, never meaning).

Project settings only load when Claude Code is started in the project
directory, so start sessions from `sturdy/`.

## 11. Evidence that it works

- **Both drivers green:** 44 runs, repeated across random seeds, with no
  flakes and no Chrome processes left behind.
- **The layering holds.** Renaming the day view's `#groups` broke 38 of 44
  runs. A one-line change to `WebUI.day_screen/0` fixed all of them, without
  touching a spec, the DSL, or a driver. (Both edits were then reverted.)
- **The browser driver catches what the LiveView driver can't.** It found
  that a `data-confirm` button blocks on a real dialog. It also caught that
  the test server was serving stale JavaScript (see
  [section 12](#12-pitfalls-we-hit)).
- **The guard holds.** An agent `Edit` of a spec was refused by the deny
  rule, and a `sed -i` on a spec was refused by the hook.

## 12. Pitfalls we hit

These are worth knowing before building the same thing elsewhere.

- **Empty lists vanish from LiveViewTest params.** `render_change` with
  `%{"videos_sort" => []}` encodes to nothing, and the handler's pattern
  match failed. Include another field (the name) so the params map isn't
  empty.
- **`confirm()` dialogs block a headless browser.** Injecting a script with
  `Page.addScriptToEvaluateOnNewDocument` didn't take effect reliably. What
  works is evaluating `window.confirm = () => true` after each `visit/2`.
  Live navigation keeps the same `window`, so the override lasts until the
  next full page load.
- **Checkbox groups with nothing to check.** A movement with no tags submits
  `movement[tag_ids][]` as an empty list, but when no tags exist there are no
  checkboxes to find. Filling an empty choice counts as done even when no
  element matches.
- **Stale compressed assets.** `Plug.Static` with `gzip: true` serves
  `app.js.gz` when it exists. A `.gz` left behind by an earlier
  `phx.digest` shadowed the freshly built bundle, so the browser driver
  silently ran old JavaScript. Now only production serves compressed
  assets, and `mix acceptance` rebuilds assets first.
- **Measuring visibility.** `el.offsetParent` is always `null` for
  `position: fixed` elements such as toasts. Use `el.checkVisibility()`.
- **Waiting on the wrong document.** Without the leaving marker, a wait
  after `Page.navigate` can succeed on the old page.
- **Lifecycle of shared processes.** A server started from inside a test
  process dies with that test unless it's started unlinked. Stop it with
  `ExUnit.after_suite/1`.

## 13. Trade-offs and open questions

- **Polling with `Process.sleep/1`.** Project guidance discourages
  sleeping in tests, and rightly so for waiting on Erlang processes, where
  monitors and messages are better. Here, the thing being waited on is a
  browser that can't send us messages. Subscribing to CDP events would be
  the alternative, but it's more machinery for no gain in reliability.
  Polling is confined to one function in `Page`, with a timeout and a
  descriptive failure.
- **The driver layer isn't in the coverage report.** `test/support` is
  excluded from ExCoveralls, as is conventional. The drivers are exercised
  by every acceptance run, and `Words`, the one pure module, has unit tests.
- **`@spec` on driver implementations.** The `@impl` functions rely on the
  behaviour's `@callback` specs rather than repeating them. Dialyzer checks
  them against the callbacks.
- **`mix format` touches specs.** It's layout only, but it's the one way
  the precommit can change a held-back file.
- **The LiveView driver simulates the client.** It's fast and precise, but
  where it sends "the event the client would send", it trusts that
  assumption. The browser driver is what checks it.
- **Tags compare as a set** because the movement page doesn't promise an
  order. If the app starts ordering tags, the DSL can compare lists.

## 14. Copying this into another project

In this order:

1. **Put a clock seam in front of every "now".** A behaviour with
   `utc_now/0`, a system implementation, and a settable test
   implementation that falls back to real time. Replace every direct call.
2. **Create the stage.** An `:acceptance` tag excluded in `test_helper.exs`,
   a mix alias (`test --only acceptance`, building assets first if a browser
   driver will run), and its preferred env.
3. **Write the driver behaviour first, in domain terms.** Ask "what does a
   user do and see?", not "what pages are there?". Use typed callbacks,
   neutral return data, and opaque refs.
4. **Write the case template and the session.** Parameterize over drivers,
   use a shared sandbox with `async: false`, and order `on_exit` so the
   driver stops before the sandbox and clock go away.
5. **Write the DSL, then a handful of specs** using it. Keep defaults, date
   words, vocabulary, targeting, and assertions in the DSL.
6. **Write the cheapest driver first** (LiveViewTest here), with all screen
   knowledge in a shared `WebUI` module. Add `data-*` attributes to the
   markup where drivers need to read meaning.
7. **Add the faithful driver** (a browser). Reuse `WebUI`; the new work is
   the transport and waiting. Run every spec on both.
8. **Prove the layering.** Rename an id in the markup and check that only
   `WebUI` needs to change.
9. **Hand the specs to their owners**, then hold them back: an agent
   instructions file, deny rules, and a hook with its own tests.

The patterns worth copying exactly:

- the session piped through every step;
- the DSL calling only behaviour callbacks;
- one shared screen-knowledge module;
- landmarks plus a settle check for waiting.

The rest (CDP over a pipe, Bandit as a plug) is one way to fill in the
transport, and can be swapped for whatever suits the other project.
