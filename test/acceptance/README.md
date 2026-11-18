# Acceptance tests

Executable specifications in the style Dave Farley describes: tests written in
the language of the problem domain that say **what** the system does, never
**how** it does it, and run against the real system through interchangeable
protocol drivers.

This is the quick reference. For the design, an end-to-end walkthrough, the
pitfalls, and how to copy the approach, see
[`docs/acceptance-testing.md`](../../docs/acceptance-testing.md).

```
mix acceptance                          # every spec on every driver
STURDY_DRIVER=live_view mix acceptance  # just one driver (live_view | browser)
mix precommit                           # unit stage (coverage ≥ 95%), then this stage
```

`mix test` skips this stage (`@moduletag :acceptance`, excluded in
`test_helper.exs`). Each spec is reported once per driver.

## The four layers

Each layer knows only the one directly below it.

| Layer | What it is | Where | Knows about |
|---|---|---|---|
| 1. Executable specifications | Test cases in domain language | `test/acceptance/specs/` | the DSL |
| 2. DSL | The language the specs use | `test/support/acceptance/dsl.ex` (+ `words.ex`) | the driver behaviour |
| 3. Protocol drivers | Carry out DSL calls through one channel | `test/support/acceptance/driver.ex`, `drivers/`, `web_ui.ex`, `browser/` | the system's UI |
| 4. System under test | The real app: router, LiveViews, database | `lib/` | — |

```elixir
test "marking a planned set done records it now, and the day shows progress", %{sturdy: s} do
  s
  |> given_it_is("2026-11-10 08:00")
  |> given_movement("Push-up")
  |> plan("Push-up", sets: 3, reps: 12)
  |> given_it_is("2026-11-10 09:15")
  |> mark_done("Push-up")
  |> expect_day("Push-up", done: 1, pending: 2)
  |> expect_done("Push-up", summary: "12 reps", at: "09:15", unplanned: false)
end
```

### 1. Specs

- Domain words only: no DOM ids, routes, forms, Ecto, or which driver runs.
- A session value (`%{sturdy: s}`) is piped through every step.
- One behaviour per test, named for the rule it pins down.
- **Specs are owned by people.** The code below them exists to make them
  pass. When a spec looks wrong, the question goes to its owner; nobody
  "fixes" a spec to match the code. Agents are blocked from writing here
  (see "Held-back specs").

### 2. DSL (`Sturdy.Acceptance.DSL`)

Turns spec phrasing into driver calls:

- **Date and time words**: `"today"`, `"tomorrow"`, `"in 3 days"`,
  `"2026-11-10 08:00"`, resolved against the controllable clock
  (`Sturdy.Acceptance.Words`, which has its own unit test).
- **Defaults**: `sets: 1`, `on: "today"`.
- **Vocabulary**: spec words such as `hold:` and `load:` map to domain fields
  (`duration_s`, `weight_lb`).
- **Targeting**: "mark the Push-up done" means the first pending Push-up entry
  on that day (optionally `side:`).
- **Comparison**: drivers return neutral data, the DSL asserts on it, and
  summaries compare without separators (`"30s L"` matches `"30s · L"`).

The DSL calls only `Sturdy.Acceptance.Driver` callbacks. It controls time
directly (`Sturdy.SettableClock`) because every driver runs in this VM.

### 3. Drivers

`Sturdy.Acceptance.Driver` is the contract: typed callbacks in domain terms
(`plan_sets/2`, `act/4`, `read_day/2`, …). Two drivers implement it:

- **`LiveViewDriver`**: in-process via `Phoenix.LiveViewTest`. Fast (~1.5s for
  all specs) but without JavaScript. Where the page relies on the client (JS
  commands, `confirm`), the driver sends the event the client would send.
- **`BrowserDriver`**: headless Chrome at phone size, against the app served
  over HTTP. It's slower (~12s) and the most faithful, with websockets,
  LiveView's JS client, and real DOM events.

Both drive the same screens, so they share **`WebUI`**: page paths, element
selectors, form field names, and readers that parse a rendered screen back
into driver types. **When markup changes, `WebUI` is the place that changes.**
(Checked: renaming the day view's `#groups` broke 38 of 44 specs. A one-line
change in `WebUI` fixed them all, with no spec, DSL, or driver touched.)

The day view's markup carries `data-*` attributes (`data-state`, `data-side`,
`data-summary`, `data-planned`, `data-time`, `data-action`, `data-movement`)
that describe each entry for machines. Drivers read meaning from them instead
of from styling or visible text.

### Browser plumbing (custom, dependency-free)

- `browser/cdp.ex`: a Chrome DevTools Protocol client. Chrome runs with
  `--remote-debugging-pipe` behind an Erlang port; messages are NUL-terminated
  JSON on fds 3/4. There's no chromedriver, Node, or WebSocket library.
- `browser/page.ex`: one tab. It visits pages, clicks, fills fields
  (dispatching `input`/`change` so LiveView sees typing), and submits. Each
  step waits for the page to **settle** (LiveView connected, no `phx-*-loading`
  class), and navigating steps wait for the next screen's **landmark**.
  Waiting means polling (`Process.sleep` between checks), because the
  browser can't send us an Erlang message.
- `browser/runtime.ex`: one Bandit server for the endpoint (on a free port)
  and one Chrome per run. Both start on first use and stop after the suite.
  `CHROME_PATH` overrides the Chrome binary.

## Isolation and time

- **Database**: Ecto sandbox in *shared* mode. Specs are `async: false`, so the
  browser's server-side processes use the running spec's connection, with no
  sandbox plug or metadata plumbing.
- **Clock**: production reads time through `Sturdy.Clock`. In tests that's
  `Sturdy.SettableClock`, which tells real time until a spec sets it and is
  reset after every spec.

## Adding a spec

1. Write it in domain words using existing DSL steps if possible.
2. If a step is missing, add it to the DSL in domain terms.
3. If the DSL needs a new capability, add a callback to `Driver`, implement
   it in **both** drivers, and put the screen knowledge in `WebUI`.
4. `mix acceptance`.

## Held-back specs

Specs are the humans' statement of what the system must do, so coding agents
may change layers 2–4 but never layer 1. In this repo Claude Code enforces
that in `.claude/settings.json`:

- A `deny` rule `Edit(test/acceptance/specs/**)`. File-path rules use `Edit`
  for every file-writing tool (Edit, Write, NotebookEdit).
- A `PreToolUse` hook (`.claude/hooks/protect_specs.py`) on the file tools
  and `Bash`, as a second layer:
  - File tools: refuses any target inside the directory, after resolving
    `..` and symlinks.
  - Shell commands that mention the directory: refused unless every part is
    known to be read-only (`cat`, `grep`, `sed -n`, `git diff`,
    `mix acceptance`, …). Writes, redirection, `tee`, interpreters
    (`python -c`, `perl -i`), `git checkout`/`restore`, `find -delete` and
    anything unrecognised are refused. It's an allowlist: unknown means no.
  - The hook has its own tests: `python3 -m unittest discover .claude/hooks`.

`AGENTS.md` states the rule for any agent.

Limits, on purpose: this is a guardrail against an agent "fixing" a spec to
get green, not a security boundary. A command that never names the
directory (say, a variable built at runtime) isn't caught. Likewise a plain
`mix format` (part of `mix precommit`) reformats specs along with
everything else. That's layout only, never meaning.

## Copying this into another project

1. Put a clock seam (behaviour + settable test clock) in front of every "now".
2. Create the stage: a `:acceptance` tag excluded by default, plus a mix alias.
3. Write the driver behaviour in domain terms first, then the DSL, then specs.
4. Write the first driver against the cheapest channel, then add more.
5. Keep all screen knowledge in one shared module (`WebUI` here).
6. Protect the specs directory from agents once the specs are reviewed.
