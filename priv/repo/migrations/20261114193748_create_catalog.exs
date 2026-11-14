defmodule Sturdy.Repo.Migrations.CreateCatalog do
  use Ecto.Migration

  def change do
    create table(:tag_categories) do
      add :name, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:tag_categories, ["lower(name)"], name: :tag_categories_name_index)

    create table(:tags) do
      add :name, :string, null: false

      add :tag_category_id, references(:tag_categories, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tags, [:tag_category_id, "lower(name)"],
             name: :tags_tag_category_id_name_index
           )

    create table(:movements) do
      add :name, :string, null: false
      add :notes, :text
      timestamps(type: :utc_datetime)
    end

    create unique_index(:movements, ["lower(name)"], name: :movements_name_index)

    create table(:movement_videos) do
      add :url, :text, null: false
      add :label, :string
      add :movement_id, references(:movements, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime)
    end

    create index(:movement_videos, [:movement_id])

    create table(:movement_tags, primary_key: false) do
      add :movement_id, references(:movements, on_delete: :delete_all), null: false
      add :tag_id, references(:tags, on_delete: :delete_all), null: false
    end

    create unique_index(:movement_tags, [:movement_id, :tag_id])
    create index(:movement_tags, [:tag_id])
  end
end
