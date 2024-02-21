defmodule Stow.Source.HttpSource do
  @moduledoc """
  Sourcing data via http protocol.
  """
  @behaviour Stow.Source

  alias Plug.Conn
  alias Stow.Http.Client

  @schemes [:http, :https]

  @impl true
  def get(%Conn{scheme: scheme, method: "GET"} = conn, opts) when scheme in @schemes do
    client = Keyword.get(opts, :http_client) || Client.impl()
    client.dispatch(conn, opts)
  end
end
