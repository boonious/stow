defmodule Stow.Source.Http do
  @moduledoc """
  Sourcing data via http protocol.
  """

  @behaviour Stow

  @impl true
  def call(%Stow.Conn{method: :get} = conn) do
    conn |> conn.adapter.dispatch()
  end
end
