defmodule Sturdy.Repo.Migrations.CreateTraining do
  use Ecto.Migration

  @measured "reps IS NOT NULL OR duration_s IS NOT NULL OR distance_m IS NOT NULL"

  def change do
    create table(:planned_sets) do
      add :movement_id, references(:movements, on_delete: :restrict), null: false
      add :planned_on, :date, null: false
      add :status, :string, null: false, default: "pending"
      metric_columns()
      timestamps(type: :utc_datetime)
    end

    create index(:planned_sets, [:planned_on])
    create index(:planned_sets, [:movement_id])
    create constraint(:planned_sets, :planned_sets_measured, check: @measured)

    create table(:completed_sets) do
      add :movement_id, references(:movements, on_delete: :restrict), null: false
      add :planned_set_id, references(:planned_sets, on_delete: :restrict)
      add :completed_at, :utc_datetime, null: false
      metric_columns()
      timestamps(type: :utc_datetime)
    end

    create unique_index(:completed_sets, [:planned_set_id])
    create index(:completed_sets, [:completed_at])
    create index(:completed_sets, [:movement_id])
    create constraint(:completed_sets, :completed_sets_measured, check: @measured)
  end

  defp metric_columns do
    add :side, :string
    add :reps, :integer
    add :duration_s, :integer
    add :distance_m, :integer
    add :weight_lb, :decimal, precision: 7, scale: 2
    add :notes, :text
  end
end
