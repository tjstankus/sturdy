defmodule SturdyWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use SturdyWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @tabs [
    {:day, "Day", "hero-calendar-days", "/"},
    {:movements, "Movements", "hero-bolt", "/movements"},
    {:tags, "Tags", "hero-tag", "/tags"},
    {:body, "Body", "hero-scale", "/bodyweight"}
  ]

  @doc """
  The mobile app shell: a sticky title bar, the page content, and a bottom tab
  bar within thumb reach.

  ## Examples

      <Layouts.app flash={@flash} title="Movements" tab={:movements}>
        <:actions><.link navigate={~p"/movements/new"}>New</.link></:actions>
        ...
      </Layouts.app>
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :title, :string, required: true
  attr :tab, :atom, required: true, values: Enum.map(@tabs, &elem(&1, 0))
  attr :back, :string, default: nil, doc: "path for a back link in the title bar"

  slot :inner_block, required: true
  slot :actions, doc: "controls at the right of the title bar"

  def app(assigns) do
    assigns = assign(assigns, :tabs, @tabs)

    ~H"""
    <div class="min-h-dvh bg-base-200 text-base-content">
      <header class="sticky top-0 z-20 border-b border-base-300 bg-base-100/90 backdrop-blur pt-[env(safe-area-inset-top)]">
        <div class="mx-auto flex h-14 max-w-xl items-center gap-1 px-2">
          <.link
            :if={@back}
            id="back-link"
            navigate={@back}
            class="rounded-full p-2 active:bg-base-200"
            aria-label="Back"
          >
            <.icon name="hero-chevron-left" class="size-6" />
          </.link>
          <h1 class={["flex-1 truncate text-lg font-semibold", !@back && "pl-2"]}>{@title}</h1>
          <div class="flex items-center gap-1">{render_slot(@actions)}</div>
        </div>
      </header>

      <main class="mx-auto max-w-xl px-4 pt-4 pb-32">
        {render_slot(@inner_block)}
      </main>

      <nav
        id="tab-bar"
        class="fixed inset-x-0 bottom-0 z-20 border-t border-base-300 bg-base-100 pb-[env(safe-area-inset-bottom)]"
      >
        <ul class="mx-auto grid max-w-xl grid-cols-4">
          <li :for={{tab, label, icon, path} <- @tabs}>
            <.link
              id={"tab-#{tab}"}
              navigate={path}
              class={[
                "flex flex-col items-center gap-0.5 py-2 text-xs transition-colors",
                if(tab == @tab, do: "text-primary font-semibold", else: "text-base-content/60")
              ]}
              aria-current={tab == @tab && "page"}
            >
              <.icon name={icon} class="size-6" />
              {label}
            </.link>
          </li>
        </ul>
      </nav>

      <.flash_group flash={@flash} />
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <%!-- Notices dismiss themselves; errors stay until dismissed. --%>
      <.flash kind={:info} flash={@flash} phx-hook=".AutoDismiss" data-dismiss-after="2500" />
      <script :type={Phoenix.LiveView.ColocatedHook} name=".AutoDismiss">
        // Dismisses the flash after data-dismiss-after ms, the same way a tap
        // does: clicking runs its phx-click (clear the flash, then hide it).
        export default {
          mounted() { this.schedule() },
          updated() { this.schedule() },
          destroyed() { clearTimeout(this.timer) },
          schedule() {
            clearTimeout(this.timer)
            this.timer = setTimeout(() => this.el.click(), Number(this.el.dataset.dismissAfter))
          }
        }
      </script>
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
