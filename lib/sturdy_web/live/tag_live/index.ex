defmodule SturdyWeb.TagLive.Index do
  @moduledoc """
  Tag categories and their tags: add, rename, delete. Muscles are tags too.
  """

  use SturdyWeb, :live_view

  alias Sturdy.Catalog
  alias Sturdy.Catalog.Tag
  alias Sturdy.Catalog.TagCategory
  alias SturdyWeb.Errors

  # Categories and tags are edited the same way; this says how for each kind.
  @kinds %{
    "category" => %{
      get: &Catalog.get_tag_category!/1,
      change: &Catalog.change_tag_category/2,
      update: &Catalog.update_tag_category/2,
      delete: &Catalog.delete_tag_category/1
    },
    "tag" => %{
      get: &Catalog.get_tag!/1,
      change: &Catalog.change_tag/2,
      update: &Catalog.update_tag/2,
      delete: &Catalog.delete_tag/1
    }
  }
  @kind_names Map.keys(@kinds)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(page_title: "Tags", editing: nil)
     |> assign(category_form: to_form(Catalog.change_tag_category(%TagCategory{})))
     |> assign(tag_form: to_form(Catalog.change_tag(%Tag{})))
     |> load()}
  end

  @impl true
  def handle_event("create_category", %{"tag_category" => params}, socket) do
    case Catalog.create_tag_category(params) do
      {:ok, _category} ->
        {:noreply,
         socket
         |> assign(category_form: to_form(Catalog.change_tag_category(%TagCategory{})))
         |> load()}

      {:error, changeset} ->
        {:noreply, assign(socket, category_form: to_form(changeset))}
    end
  end

  def handle_event("create_tag", %{"tag" => params}, socket) do
    case Catalog.create_tag(params) do
      {:ok, tag} ->
        fresh = Catalog.change_tag(%Tag{tag_category_id: tag.tag_category_id})
        {:noreply, socket |> assign(tag_form: to_form(fresh)) |> load()}

      {:error, changeset} ->
        {:noreply, assign(socket, tag_form: to_form(changeset))}
    end
  end

  def handle_event("edit", %{"kind" => kind, "id" => id}, socket) when kind in @kind_names do
    %{get: get, change: change} = Map.fetch!(@kinds, kind)
    record = get.(id)

    {:noreply,
     assign(socket,
       editing: {kind, record.id},
       editing_record: record,
       edit_form: to_form(change.(record, %{}), as: :item)
     )}
  end

  def handle_event("cancel_edit", _params, socket), do: {:noreply, assign(socket, editing: nil)}

  def handle_event(
        "save_edit",
        %{"item" => params},
        %{assigns: %{editing: {kind, _id}, editing_record: record}} = socket
      ) do
    case Map.fetch!(@kinds, kind).update.(record, params) do
      {:ok, _record} -> {:noreply, socket |> assign(editing: nil) |> load()}
      {:error, changeset} -> {:noreply, assign(socket, edit_form: to_form(changeset, as: :item))}
    end
  end

  def handle_event("delete", %{"kind" => kind, "id" => id}, socket) when kind in @kind_names do
    %{get: get, delete: delete} = Map.fetch!(@kinds, kind)

    socket =
      case id |> get.() |> delete.() do
        {:ok, _record} -> socket
        {:error, changeset} -> put_flash(socket, :error, Errors.summary(changeset))
      end

    {:noreply, load(socket)}
  end

  defp load(socket), do: assign(socket, categories: Catalog.list_tag_categories())

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} title="Tags" tab={:tags}>
      <p class="mb-3 text-sm text-base-content/60">
        Group tags into categories, e.g. <em>muscle</em>
        (pecs, glutes) or <em>modality</em>
        (isometric).
      </p>

      <section
        :for={category <- @categories}
        id={"category-#{category.id}"}
        class="mb-3 overflow-hidden rounded-box bg-base-100 shadow-sm"
      >
        <.item_row
          kind="category"
          record={category}
          editing={@editing}
          edit_form={assigns[:edit_form]}
          class="bg-base-300/40 font-semibold"
        >
          {category.name}
        </.item_row>
        <ul class="divide-y divide-base-200">
          <li :for={tag <- category.tags}>
            <.item_row kind="tag" record={tag} editing={@editing} edit_form={assigns[:edit_form]}>
              {tag.name}
            </.item_row>
          </li>
          <li :if={category.tags == []} class="px-4 py-2 text-sm text-base-content/60">
            No tags yet.
          </li>
        </ul>
      </section>

      <section :if={@categories != []} class="mb-3 rounded-box bg-base-100 p-4">
        <h2 class="mb-2 font-semibold">Add a tag</h2>
        <.form for={@tag_form} id="tag-form" phx-submit="create_tag">
          <.input
            field={@tag_form[:tag_category_id]}
            type="select"
            label="Category"
            options={Enum.map(@categories, &{&1.name, &1.id})}
          />
          <.input field={@tag_form[:name]} label="Name" autocomplete="off" />
          <button type="submit" class="btn btn-primary w-full">Add tag</button>
        </.form>
      </section>

      <section class="rounded-box bg-base-100 p-4">
        <h2 class="mb-2 font-semibold">Add a category</h2>
        <.form for={@category_form} id="category-form" phx-submit="create_category">
          <.input
            field={@category_form[:name]}
            label="Name"
            placeholder="e.g. muscle"
            autocomplete="off"
          />
          <button type="submit" class="btn btn-outline w-full">Add category</button>
        </.form>
      </section>
    </Layouts.app>
    """
  end

  # A category or tag line: its name with rename/delete controls, or an inline
  # rename form while it is being edited.
  attr :kind, :string, required: true
  attr :record, :map, required: true
  attr :editing, :any, required: true
  attr :edit_form, :any, required: true
  attr :class, :any, default: nil
  slot :inner_block, required: true

  defp item_row(assigns) do
    assigns = assign(assigns, :dom_id, "#{assigns.kind}-row-#{assigns.record.id}")

    ~H"""
    <div id={@dom_id} class={["flex items-center gap-2 px-4 py-2", @class]}>
      <%= if @editing == {@kind, @record.id} do %>
        <.form
          for={@edit_form}
          id={"#{@dom_id}-form"}
          phx-submit="save_edit"
          class="flex flex-1 items-start gap-2"
        >
          <div class="flex-1"><.input field={@edit_form[:name]} autocomplete="off" /></div>
          <button type="submit" class="btn btn-primary btn-sm mt-1">Save</button>
          <button type="button" phx-click="cancel_edit" class="btn btn-ghost btn-sm mt-1">Cancel</button>
        </.form>
      <% else %>
        <span class="flex-1">{render_slot(@inner_block)}</span>
        <button
          id={"#{@dom_id}-edit"}
          phx-click="edit"
          phx-value-kind={@kind}
          phx-value-id={@record.id}
          class="p-2 text-base-content/60"
          aria-label="Rename"
        >
          <.icon name="hero-pencil" class="size-4" />
        </button>
        <button
          id={"#{@dom_id}-delete"}
          phx-click="delete"
          phx-value-kind={@kind}
          phx-value-id={@record.id}
          data-confirm={"Delete this #{@kind}?"}
          class="p-2 text-base-content/60"
          aria-label="Delete"
        >
          <.icon name="hero-trash" class="size-4" />
        </button>
      <% end %>
    </div>
    """
  end
end
