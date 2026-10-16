defmodule FootballBackend.Football.SyncWorker do
  use GenServer
  require Logger

  @initial_delay_ms 60_000
  @on_demand_cooldown_ms 15 * 60 * 1_000

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def request_sync(league_id, season),
    do: GenServer.cast(__MODULE__, {:request_sync, league_id, season})

  @impl true
  def init(:ok) do
    schedule(@initial_delay_ms)

    {:ok,
     %{
       interval:
         Application.get_env(:football_backend, FootballBackend.Football, [])
         |> Keyword.get(:sync_interval_ms, 6 * 60 * 60 * 1_000),
       pending: MapSet.new(),
       requested_at: %{},
       request_scheduled?: false
     }}
  end

  @impl true
  def handle_cast({:request_sync, league_id, season}, state) do
    scope = {league_id, season}
    now = System.monotonic_time(:millisecond)
    last = Map.get(state.requested_at, scope, now - @on_demand_cooldown_ms)

    if now - last >= @on_demand_cooldown_ms and not MapSet.member?(state.pending, scope) do
      state = %{
        state
        | pending: MapSet.put(state.pending, scope),
          requested_at: Map.put(state.requested_at, scope, now)
      }

      unless state.request_scheduled? do
        Process.send_after(self(), :requested_sync, 0)
      end

      {:noreply, %{state | request_scheduled?: true}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:requested_sync, %{pending: pending} = state) do
    case Enum.at(pending, 0) do
      nil ->
        {:noreply, %{state | request_scheduled?: false}}

      {league_id, season} = scope ->
        case FootballBackend.Football.sync(league_id, season) do
          :ok ->
            Logger.info(
              "On-demand football sync completed for league #{league_id}, season #{season}"
            )

          {:error, reason} ->
            Logger.warning(
              "On-demand football sync failed for league #{league_id}, season #{season}: #{inspect(reason)}"
            )
        end

        pending = MapSet.delete(state.pending, scope)
        if MapSet.size(pending) > 0, do: Process.send_after(self(), :requested_sync, 0)
        {:noreply, %{state | pending: pending, request_scheduled?: MapSet.size(pending) > 0}}
    end
  rescue
    error ->
      Logger.error(
        "On-demand football sync crashed: #{Exception.format(:error, error, __STACKTRACE__)}"
      )

      pending =
        case Enum.at(state.pending, 0) do
          nil -> state.pending
          scope -> MapSet.delete(state.pending, scope)
        end

      if MapSet.size(pending) > 0, do: Process.send_after(self(), :requested_sync, 0)
      {:noreply, %{state | pending: pending, request_scheduled?: MapSet.size(pending) > 0}}
  end

  @impl true
  def handle_info(:sync, state) do
    if Application.get_env(:football_backend, FootballBackend.Football, [])
       |> Keyword.get(:enabled, true) do
      case FootballBackend.Football.sync() do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning("Scheduled football data sync skipped: #{inspect(reason)}")
      end
    end

    schedule(state.interval)
    {:noreply, state}
  rescue
    error ->
      Logger.error(
        "Scheduled API-Football sync crashed: #{Exception.format(:error, error, __STACKTRACE__)}"
      )

      schedule(state.interval)
      {:noreply, state}
  end

  defp schedule(delay), do: Process.send_after(self(), :sync, delay)
end
