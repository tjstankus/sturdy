defmodule Sturdy.Catalog.MovementVideo do
  @moduledoc """
  A video reference for a movement. Any start offset is part of the URL itself.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias Sturdy.Catalog.Movement
  alias Sturdy.Changesets

  @type t :: %__MODULE__{
          id: integer() | nil,
          url: String.t() | nil,
          label: String.t() | nil,
          movement_id: integer() | nil,
          movement: Movement.t() | Ecto.Association.NotLoaded.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  schema "movement_videos" do
    field :url, :string
    field :label, :string

    belongs_to :movement, Movement

    timestamps(type: :utc_datetime)
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(video, attrs) do
    video
    |> cast(attrs, [:url, :label])
    |> Changesets.trim(:url)
    |> Changesets.trim(:label)
    |> validate_required([:url])
    |> validate_length(:label, max: 120)
    |> validate_change(:url, fn :url, url ->
      case URI.new(url) do
        {:ok, %URI{scheme: scheme, host: host}}
        when scheme in ["http", "https"] and is_binary(host) and host != "" ->
          []

        _invalid ->
          [url: "must be an http or https URL"]
      end
    end)
  end
end
