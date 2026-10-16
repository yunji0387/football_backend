defmodule FootballBackend.Football.TelegramNotifier do
  require Logger

  alias FootballBackend.Football.SyncRun

  def progress(%SyncRun{} = run) do
    send_message(
      "Football sync #{run.league_id}/#{run.season}: page #{run.current_page}/#{run.total_pages || "?"}; fetched #{run.records_fetched}, saved #{run.records_saved} player-stat rows."
    )
  end

  def completed(%SyncRun{} = run) do
    send_message(
      "Football sync completed for league #{run.league_id}, season #{run.season}: fetched #{run.records_fetched}, saved #{run.records_saved} player-stat rows across #{run.total_pages || run.current_page} pages."
    )
  end

  def failed(%SyncRun{} = run) do
    send_message(
      "Football sync paused for league #{run.league_id}, season #{run.season} at page #{run.current_page}/#{run.total_pages || "?"}. Saved #{run.records_saved} player-stat rows. Error: #{run.error}"
    )
  end

  defp send_message(text) do
    config = Application.get_env(:football_backend, FootballBackend.Football, [])
    token = Keyword.get(config, :telegram_bot_token)
    chat_id = Keyword.get(config, :telegram_chat_id)

    if is_binary(token) and token != "" and is_binary(chat_id) and chat_id != "" do
      url = String.to_charlist("https://api.telegram.org/bot#{token}/sendMessage")
      headers = [{~c"content-type", ~c"application/json"}]
      body = Jason.encode!(%{chat_id: chat_id, text: text})

      case :httpc.request(
             :post,
             {url, headers, ~c"application/json", body},
             [timeout: 10_000, connect_timeout: 5_000],
             body_format: :binary
           ) do
        {:ok, {{_, status, _}, _, _}} when status in 200..299 ->
          :ok

        {:ok, {{_, status, _}, _, _}} ->
          Logger.warning("Telegram sync notification failed with HTTP #{status}")

        {:error, reason} ->
          Logger.warning("Telegram sync notification failed: #{inspect(reason)}")
      end
    else
      :ok
    end
  rescue
    error ->
      Logger.warning("Telegram sync notification failed: #{Exception.message(error)}")
      :ok
  end
end
