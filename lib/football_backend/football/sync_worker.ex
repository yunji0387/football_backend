defmodule FootballBackend.Football.SyncWorker do
  use GenServer
  require Logger

  @initial_delay_ms 60_000

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok) do
    schedule(@initial_delay_ms)
    {:ok, %{interval: Application.get_env(:football_backend, FootballBackend.Football, []) |> Keyword.get(:sync_interval_ms, 6 * 60 * 60 * 1_000)}}
  end

  @impl true
  def handle_info(:sync, state) do
    if Application.get_env(:football_backend, FootballBackend.Football, []) |> Keyword.get(:enabled, true) do
      case FootballBackend.Football.sync() do
        :ok -> :ok
        {:error, reason} -> Logger.warning("Scheduled API-Football sync skipped: #{inspect(reason)}")
      end
    end

    schedule(state.interval)
    {:noreply, state}
  rescue
    error ->
      Logger.error("Scheduled API-Football sync crashed: #{Exception.format(:error, error, __STACKTRACE__)}")
      schedule(state.interval)
      {:noreply, state}
  end

  defp schedule(delay), do: Process.send_after(self(), :sync, delay)
end
