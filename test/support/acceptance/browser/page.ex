defmodule Sturdy.Acceptance.Browser.Page do
  @moduledoc """
  One browser tab, driven through `Sturdy.Acceptance.Browser.CDP`.

  The tab emulates a phone (390×844) and accepts every `confirm()` dialog.
  Interaction happens by evaluating JavaScript in the page: clicks are real
  DOM clicks, and filled fields dispatch `input` and `change` events so
  LiveView sees them as typing would.

  LiveView updates arrive asynchronously, so each step waits for the page to
  *settle*: the LiveView is connected and no `phx-*-loading` class remains.
  Steps that navigate wait instead for a landmark of the next screen.
  """

  alias Sturdy.Acceptance.Browser.CDP

  @enforce_keys [:cdp, :target_id, :session_id]
  defstruct [:cdp, :target_id, :session_id]

  @type t :: %__MODULE__{cdp: CDP.t(), target_id: String.t(), session_id: String.t()}

  @timeout_ms 5_000
  @poll_ms 20
  @settled """
  !!document.querySelector('[data-phx-main].phx-connected') &&
    !document.querySelector('.phx-click-loading, .phx-submit-loading, .phx-change-loading')
  """

  @spec open(CDP.t()) :: t()
  def open(cdp) do
    {:ok, %{"targetId" => target_id}} =
      CDP.command(cdp, "Target.createTarget", %{url: "about:blank"})

    {:ok, %{"sessionId" => session_id}} =
      CDP.command(cdp, "Target.attachToTarget", %{targetId: target_id, flatten: true})

    page = %__MODULE__{cdp: cdp, target_id: target_id, session_id: session_id}

    command!(page, "Emulation.setDeviceMetricsOverride", %{
      width: 390,
      height: 844,
      deviceScaleFactor: 3,
      mobile: true
    })

    page
  end

  @spec close(t()) :: :ok
  def close(%__MODULE__{} = page) do
    {:ok, _result} = CDP.command(page.cdp, "Target.closeTarget", %{targetId: page.target_id})
    :ok
  end

  @doc "Loads a URL and waits for its LiveView to connect."
  @spec visit(t(), String.t()) :: t()
  def visit(page, url) do
    # Mark the current document so the wait can't mistake it for the new one.
    eval(page, "window.__sturdyLeaving = true")
    command!(page, "Page.navigate", %{url: url})
    wait_until(page, "!window.__sturdyLeaving && #{@settled}", "#{url} to load")
    # Live navigation keeps this window, so the answer holds until the next visit.
    eval(page, "window.confirm = () => true")
    page
  end

  @doc "Clicks the element matching `selector`, then waits for the page to settle."
  @spec click(t(), String.t()) :: t()
  def click(page, selector) do
    found? =
      eval(page, """
      (() => {
        const el = document.querySelector(#{Jason.encode!(selector)});
        el && el.click();
        return !!el;
      })()
      """)

    found? || raise "nothing to click at #{selector}"
    settle(page)
  end

  @doc """
  Fills fields from nested form params (as a browser would submit them),
  one field at a time, letting LiveView respond to each.
  """
  @spec fill_form(t(), map()) :: t()
  def fill_form(page, params) do
    params
    |> fields(nil)
    |> Enum.reduce(page, fn {name, value}, page -> fill(page, name, value) end)
  end

  @doc "Submits the form matching `selector`, then waits for the reply."
  @spec submit(t(), String.t()) :: t()
  def submit(page, selector) do
    eval(page, "document.querySelector(#{Jason.encode!(selector)}).requestSubmit()")
    settle(page)
  end

  @doc "Waits until one of `selectors` is present; returns the first that is."
  @spec wait_for_any(t(), [String.t()]) :: String.t()
  def wait_for_any(page, selectors) do
    present = "#{Jason.encode!(selectors)}.find(s => document.querySelector(s))"
    wait_until(page, "(#{@settled}) && #{present}", "any of #{inspect(selectors)}")
    eval(page, present)
  end

  @doc "Waits until `selector` is present on a settled page."
  @spec wait_for(t(), String.t()) :: t()
  def wait_for(page, selector) do
    present = "!!document.querySelector(#{Jason.encode!(selector)})"
    wait_until(page, "(#{@settled}) && #{present}", selector)
  end

  @spec html(t()) :: String.t()
  def html(page), do: eval(page, "document.documentElement.outerHTML")

  @doc "Evaluates JavaScript in the page and returns its (JSON-able) value."
  @spec eval(t(), String.t()) :: term()
  def eval(page, expression) do
    result =
      command!(page, "Runtime.evaluate", %{
        expression: expression,
        returnByValue: true,
        awaitPromise: true
      })

    value = fn
      %{"exceptionDetails" => details} -> raise "JavaScript failed: #{inspect(details)}"
      %{"result" => result} -> result["value"]
    end

    value.(result)
  end

  defp settle(page), do: wait_until(page, @settled, "the page to settle")

  defp fill(page, name, value) do
    filled? =
      eval(page, """
      ((name, value) => {
        const els = [...document.getElementsByName(name)].filter(el => el.type !== 'hidden');
        for (const el of els) {
          if (el.type === 'checkbox') el.checked = [].concat(value).includes(el.value);
          else el.value = value;
          el.dispatchEvent(new Event('input', {bubbles: true}));
          el.dispatchEvent(new Event('change', {bubbles: true}));
        }
        // An empty choice is satisfied even when there is nothing to choose from.
        return els.length > 0 || (Array.isArray(value) && value.length === 0);
      })(#{Jason.encode!(name)}, #{Jason.encode!(value)})
      """)

    filled? || raise "no field named #{name}"
    settle(page)
  end

  defp wait_until(page, condition, description, waited_ms \\ 0)

  defp wait_until(_page, _condition, description, waited_ms) when waited_ms > @timeout_ms,
    do: raise("timed out after #{@timeout_ms}ms waiting for #{description}")

  defp wait_until(page, condition, description, waited_ms) do
    case eval(page, "!!(#{condition})") do
      true ->
        page

      false ->
        Process.sleep(@poll_ms)
        wait_until(page, condition, description, waited_ms + @poll_ms)
    end
  end

  # Nested params → [{field name, value}], e.g. %{"a" => %{"b" => 1}} → [{"a[b]", 1}].
  defp fields(params, prefix) when is_map(params),
    do: Enum.flat_map(params, fn {key, value} -> fields(value, name(prefix, key)) end)

  defp fields(values, prefix) when is_list(values), do: [{prefix <> "[]", values}]
  defp fields(value, prefix), do: [{prefix, value}]

  defp name(nil, key), do: key
  defp name(prefix, key), do: "#{prefix}[#{key}]"

  defp command!(page, method, params) do
    {:ok, result} = CDP.command(page.cdp, method, params, page.session_id)
    result
  end
end
