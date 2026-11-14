defmodule Sturdy.Acceptance.WebUI do
  @moduledoc """
  What the drivers share about Sturdy's web screens: where pages are, which
  elements to act on, how form fields are named, and how to read a rendered
  screen back into the driver vocabulary (`Sturdy.Acceptance.Driver` types).

  Both drivers use the same screens and differ only in how they reach them
  (in-process LiveViewTest, or a real browser). When markup changes, this
  module, not the specs or DSL, absorbs it.
  """

  use SturdyWeb, :verified_routes

  alias Sturdy.Acceptance.Driver

  @typedoc "Form parameters as the browser would submit them, nested by prefix."
  @type params :: %{String.t() => %{String.t() => term()}}

  # The data-* vocabulary rendered by the day view.
  @states %{"pending" => :pending, "done" => :done, "skipped" => :skipped}
  @actions %{
    "mark_done" => :mark_done,
    "edit" => :edit,
    "skip" => :skip,
    "delete" => :delete,
    "undo" => :undo
  }
  @sides %{"left" => :left, "right" => :right}

  # Each edit screen's form and the prefix its fields use.
  @edit_forms %{"planned-set-form" => "planned_set", "completed-set-form" => "completed_set"}

  ## Pages

  @spec day_path(Date.t()) :: String.t()
  def day_path(date), do: ~p"/days/#{date}"

  @spec plan_path(Date.t()) :: String.t()
  def plan_path(date), do: ~p"/days/#{date}/plan"

  @spec log_path(Date.t()) :: String.t()
  def log_path(date), do: ~p"/days/#{date}/log"

  @spec tags_path() :: String.t()
  def tags_path, do: ~p"/tags"

  @spec movements_path() :: String.t()
  def movements_path, do: ~p"/movements"

  @spec new_movement_path() :: String.t()
  def new_movement_path, do: ~p"/movements/new"

  ## Landmarks: an element that shows a screen has arrived

  @spec day_screen() :: String.t()
  def day_screen, do: "#groups"

  @spec movement_screen() :: String.t()
  def movement_screen, do: "#delete-movement"

  @spec edit_screen() :: String.t()
  def edit_screen, do: @edit_forms |> Map.keys() |> Enum.map_join(", ", &"##{&1}")

  ## Elements

  @spec category_form() :: String.t()
  def category_form, do: "#category-form"

  @spec tag_form() :: String.t()
  def tag_form, do: "#tag-form"

  @spec movement_form() :: String.t()
  def movement_form, do: "#movement-form"

  @spec add_video_button() :: String.t()
  def add_video_button, do: "#add-video"

  @spec plan_form() :: String.t()
  def plan_form, do: "#plan-form"

  @spec log_form() :: String.t()
  def log_form, do: "#completed-set-form"

  @doc "The plan form's input that adds one more chosen date."
  @spec new_date_field() :: String.t()
  def new_date_field, do: "new_date"

  @spec remove_date_button(Date.t()) :: String.t()
  def remove_date_button(date), do: "#date-#{date} button"

  @spec entry_action(String.t(), Driver.action()) :: String.t()
  def entry_action(ref, action), do: ~s|##{ref} [data-action="#{action}"]|

  @spec movement_link(String.t()) :: String.t()
  def movement_link(name), do: ~s|#movements [data-movement="#{name}"] a|

  @spec tag_filter(String.t(), String.t()) :: String.t()
  def tag_filter(html, tag) do
    html
    |> LazyHTML.from_document()
    |> LazyHTML.query("#tag-filter a")
    |> find_by_text!(tag)
    |> attribute()
    |> then(&"##{&1}")
  end

  ## Plan form: which date the form opens on, and how its chosen dates change

  @doc "The plan form opens on the plan's first day; that day comes pre-chosen."
  @spec plan_start(Driver.plan()) :: Date.t()
  def plan_start(plan), do: Enum.min(plan.dates ++ List.wrap(plan.range_from), Date)

  @doc "Dates to add to, and remove from, the pre-chosen `[start]`."
  @spec date_changes(Driver.plan(), Date.t()) :: {[Date.t()], [Date.t()]}
  def date_changes(plan, start), do: {plan.dates -- [start], [start] -- plan.dates}

  ## Form parameters

  @doc "A set's fields as form params under `prefix`; movements resolve by name."
  @spec set_params(String.t(), String.t(), Driver.fields()) :: params()
  def set_params(html, prefix, fields) do
    param = fn
      {:movement, name} ->
        {"movement_id", option_value(html, ~s|select[name="#{prefix}[movement_id]"]|, name)}

      {field, value} ->
        {Atom.to_string(field), value(value)}
    end

    %{prefix => Map.new(fields, param)}
  end

  @spec plan_params(String.t(), Driver.plan()) :: params()
  def plan_params(html, plan) do
    schedule = %{
      "copies" => value(plan.copies),
      "per_side" => value(plan.per_side),
      "range_from" => value(plan.range_from),
      "range_to" => value(plan.range_to)
    }

    html |> set_params("planned_set", plan.set) |> Map.put("schedule", schedule)
  end

  @doc "A movement's form params; tags resolve to their checkbox values by name."
  @spec movement_params(String.t(), Driver.movement()) :: params()
  def movement_params(html, movement) do
    tag_value = fn tag ->
      html
      |> LazyHTML.from_document()
      |> LazyHTML.query(~s|#{movement_form()} label:has(input[name="movement[tag_ids][]"])|)
      |> find_by_text!(tag)
      |> LazyHTML.query("input")
      |> attribute("value")
    end

    videos =
      movement.videos
      |> Enum.with_index()
      |> Map.new(fn {video, index} ->
        {to_string(index), %{"url" => video.url, "label" => value(video.label)}}
      end)

    %{
      "movement" => %{
        "name" => movement.name,
        "notes" => value(movement.notes),
        "tag_ids" => Enum.map(movement.tags, tag_value),
        "videos" => videos
      }
    }
  end

  @spec category_params(String.t()) :: params()
  def category_params(name), do: %{"tag_category" => %{"name" => name}}

  @spec tag_params(String.t(), String.t(), String.t()) :: params()
  def tag_params(html, category, name) do
    category_id = option_value(html, ~s|#{tag_form()} select|, category)
    %{"tag" => %{"tag_category_id" => category_id, "name" => name}}
  end

  @doc "The prefix of the edit screen's form fields."
  @spec edit_prefix(String.t()) :: String.t()
  def edit_prefix(html) do
    form_id =
      html
      |> LazyHTML.from_document()
      |> LazyHTML.query(edit_screen())
      |> attribute()

    Map.fetch!(@edit_forms, form_id)
  end

  ## Reading screens

  @spec day(String.t()) :: [Driver.group()]
  def day(html) do
    maybe = fn
      nil, _parse -> nil
      text, parse -> parse.(text)
    end

    entry = fn node ->
      %{
        ref: attribute(node),
        state: Map.fetch!(@states, attribute(node, "data-state")),
        side: maybe.(attribute(node, "data-side"), &Map.fetch!(@sides, &1)),
        summary: attribute(node, "data-summary"),
        planned: attribute(node, "data-planned"),
        time: maybe.(attribute(node, "data-time"), &Time.from_iso8601!(&1 <> ":00")),
        actions:
          node
          |> LazyHTML.query("[data-action]")
          |> LazyHTML.attribute("data-action")
          |> Enum.map(&Map.fetch!(@actions, &1))
      }
    end

    html
    |> LazyHTML.from_document()
    |> LazyHTML.query("#{day_screen()} [data-movement]")
    |> Enum.map(fn group ->
      %{
        movement: attribute(group, "data-movement"),
        entries: group |> LazyHTML.query("[data-state]") |> Enum.map(entry)
      }
    end)
  end

  @spec movements(String.t()) :: [String.t()]
  def movements(html) do
    html
    |> LazyHTML.from_document()
    |> LazyHTML.query("#movements [data-movement]")
    |> LazyHTML.attribute("data-movement")
  end

  @spec movement(String.t()) :: Driver.movement_page()
  def movement(html) do
    page = LazyHTML.from_document(html)

    notes =
      case page |> LazyHTML.query("#movement-notes") |> LazyHTML.text() do
        "" -> nil
        text -> String.trim(text)
      end

    %{
      notes: notes,
      tags: page |> LazyHTML.query("#movement-tags li") |> Enum.map(&text/1),
      videos:
        page
        |> LazyHTML.query("#movement-videos a")
        |> Enum.map(&%{label: text(&1), url: attribute(&1, "href")})
    }
  end

  @doc "Validation messages and error flashes on a screen, for failure reports."
  @spec errors(String.t()) :: [String.t()]
  def errors(html) do
    html
    |> LazyHTML.from_document()
    |> LazyHTML.query(".text-error, #flash-error")
    |> Enum.map(&text/1)
  end

  ## Helpers

  defp option_value(html, select, text) do
    html
    |> LazyHTML.from_document()
    |> LazyHTML.query("#{select} option")
    |> find_by_text!(text)
    |> attribute("value")
  end

  defp find_by_text!(nodes, text) do
    Enum.find(nodes, &(text(&1) == text)) ||
      raise ArgumentError,
            "nothing reading #{inspect(text)} among #{inspect(Enum.map(nodes, &text/1))}"
  end

  defp attribute(node, name \\ "id"), do: node |> LazyHTML.attribute(name) |> List.first()

  defp text(node), do: node |> LazyHTML.text() |> String.split() |> Enum.join(" ")

  # How a domain value is written into a form field.
  defp value(nil), do: ""
  defp value(%Date{} = date), do: Date.to_iso8601(date)
  defp value(%NaiveDateTime{} = at), do: Calendar.strftime(at, "%Y-%m-%dT%H:%M")
  defp value(value) when is_atom(value), do: Atom.to_string(value)
  defp value(value), do: to_string(value)
end
