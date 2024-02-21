defmodule Stow.Http.Client do
  @moduledoc """
  HTTP client behaviour based on `t:Plug.Conn.t/0`.
  """

  @type client_options :: keyword()
  @type conn :: Plug.Conn.t()

  @type body :: Plug.Conn.body()
  @type headers :: Plug.Conn.headers()
  @type status :: Plug.Conn.status()

  @type request_url :: iodata()
  @type response :: {:ok, {status(), headers(), body()}} | {:error, term()}

  @doc """
  Dispatches HTTP request based on `t:Plug.Conn.t/0`.
  """
  @callback dispatch(conn(), client_options()) :: response()

  @doc false
  @spec build_req_url(conn()) :: request_url()
  def build_req_url(conn) do
    [
      "#{conn.scheme}://",
      conn.host,
      ":",
      "#{conn.port}",
      conn.request_path,
      if(conn.query_string == "", do: "", else: "?#{conn.query_string}")
    ]
  end

  @doc false
  @spec impl() :: module()
  def impl(), do: Application.get_env(:stow, :http_client, Stow.Http.Client.Httpc)
end
