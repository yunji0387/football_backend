defmodule FootballBackend.Matches do
  @moduledoc """
  The Matches context.
  """

  import Ecto.Query, warn: false
  alias FootballBackend.Repo
  alias FootballBackend.Matches.Match

  def list_matches do
    Repo.all(Match)
  end

  def get_match!(id), do: Repo.get!(Match, id)

  def create_match(attrs \\ %{}) do
    %Match{}
    |> Match.changeset(attrs)
    |> Repo.insert()
  end

  def update_match(%Match{} = match, attrs) do
    match
    |> Match.changeset(attrs)
    |> Repo.update()
  end

  def delete_match(%Match{} = match) do
    Repo.delete(match)
  end

  def change_match(%Match{} = match, attrs \\ %{}) do
    Match.changeset(match, attrs)
  end
end
