defmodule Stow.Http.Client do
  @moduledoc """
  HTTP client behaviour based on `t:Plug.Conn.t/0`.
  """

  @type client_options :: keyword()
  @type conn :: Plug.Conn.t()

  @type body :: Plug.Conn.body()
  @type headers :: Plug.Conn.headers()
  @type status :: Plug.Conn.status()

  @type response :: {:ok, {status(), headers(), body()}} | {:error, term()}

  @doc """
  Dispatches HTTP request based on `t:Plug.Conn.t/0`.
  """
  @callback dispatch(conn(), client_options()) :: response()
end
