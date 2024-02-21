defmodule Stow.Http.Client.Httpc do
  @moduledoc false
  @behaviour Stow.Http.Client

  import Stow.Http.Client, only: [build_req_url: 1]
  alias Plug.Conn

  @httpc_options [
    :timeout,
    :connect_timeout,
    :ssl,
    :autoredirect,
    :proxy_auth,
    :version,
    :relaxed
  ]

  @impl true
  def dispatch(%Conn{method: method} = conn, options) when method in ["GET"] do
    with {http_opts, opts} <- split_options(options, {[], []}),
         headers <- charlist_headers(conn.req_headers),
         url <- build_req_url(conn) do
      :httpc.request(:get, {url |> to_charlist(), headers}, http_opts, opts)
    end
  end

  def dispatch(_conn, _options), do: {:error, :not_supported}

  defp split_options([], {http_opts, opts}), do: {http_opts, opts}

  defp split_options([{k, v} | t], {http_opts, opts}) do
    case k in @httpc_options do
      true -> split_options(t, {[{k, v} | http_opts], opts})
      false -> split_options(t, {http_opts, [{k, v} | opts]})
    end
  end

  defp charlist_headers(headers) do
    Enum.map(headers, fn {k, v} -> {to_charlist(k), to_charlist(v)} end)
  end
end
