defmodule Stow.Source do
  @moduledoc """
  Behaviour for fetching data from various URI sources.
  """

  alias Stow.Http.Client, as: HttpClient

  @type conn :: Plug.Conn.t()
  @type options :: keyword()

  @callback get(conn(), options()) :: HttpClient.response()
end
