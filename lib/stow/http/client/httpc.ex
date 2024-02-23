defmodule Stow.Http.Client.Httpc do
  @moduledoc false
  @behaviour Stow.Http.Client

  import Stow.Http.Client, only: [build_req_url: 1]
  alias Plug.Conn

  @http_options [
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
    with {http_opts, opts} <- split_options(options, {[], []}, conn.scheme),
         headers <- charlist_headers(conn.req_headers),
         url <- build_req_url(conn) do
      :httpc.request(:get, {url |> to_charlist(), headers}, http_opts, opts)
    end
  end

  def dispatch(_conn, _options), do: {:error, :not_supported}

  defp split_options([], {http_opts, opts}, :http), do: {http_opts, opts}
  defp split_options([], {http_opts, opts}, :https), do: {http_opts |> set_ssl_opt(), opts}

  defp split_options([{k, v} | t], {http_opts, opts}, scheme) do
    case k in @http_options do
      true -> split_options(t, {[{k, v} | http_opts], opts}, scheme)
      false -> split_options(t, {http_opts, [{k, v} | opts]}, scheme)
    end
  end

  defp charlist_headers(headers) do
    Enum.map(headers, fn {k, v} -> {to_charlist(k), to_charlist(v)} end)
  end

  defp set_ssl_opt(http_opts) do
    ssl_opt = Keyword.get(http_opts, :ssl, [])
    ssl_opt = Keyword.merge(ssl_opts(), ssl_opt)

    Keyword.put(http_opts, :ssl, ssl_opt)
  end

  def ssl_opts do
    [
      verify: :verify_peer,
      cacertfile: ~c"#{CAStore.file_path()}",
      customize_hostname_check: [
        match_fun: :public_key.pkix_verify_hostname_match_fun(:https)
      ],
      versions: [:"tlsv1.2"],
      depth: 4
    ]
  end
end
