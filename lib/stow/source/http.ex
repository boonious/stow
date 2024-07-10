defmodule Stow.Source.Http do
  @moduledoc """
  Sourcing data via http protocol.
  """

  @behaviour Stow

  @impl true
  def call(%Stow{conn: %{method: :get} = conn, type: :source} = stow) do
    conn |> stow.conn.adapter.dispatch()
  end
end
