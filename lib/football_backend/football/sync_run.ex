defmodule FootballBackend.Football.SyncRun do
  use Ecto.Schema
  import Ecto.Changeset

  schema "sync_runs" do
    field :provider, :string
    field :resource, :string
    field :league_id, :integer
    field :season, :integer
    field :status, :string, default: "running"
    field :current_page, :integer, default: 0
    field :total_pages, :integer
    field :records_fetched, :integer, default: 0
    field :records_saved, :integer, default: 0
    field :error, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    timestamps(type: :utc_datetime)
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :provider,
      :resource,
      :league_id,
      :season,
      :status,
      :current_page,
      :total_pages,
      :records_fetched,
      :records_saved,
      :error,
      :started_at,
      :completed_at
    ])
    |> validate_required([:provider, :resource, :league_id, :season, :status, :started_at])
    |> validate_number(:current_page, greater_than_or_equal_to: 0)
    |> validate_number(:records_fetched, greater_than_or_equal_to: 0)
    |> validate_number(:records_saved, greater_than_or_equal_to: 0)
  end
end
