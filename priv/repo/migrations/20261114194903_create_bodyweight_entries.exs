defmodule Sturdy.Repo.Migrations.CreateBodyweightEntries do
  use Ecto.Migration

  def change do
    create table(:bodyweight_entries) do
      add :measured_on, :date, null: false
      add :weight_lb, :decimal, precision: 5, scale: 1, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:bodyweight_entries, [:measured_on])
  end
end
