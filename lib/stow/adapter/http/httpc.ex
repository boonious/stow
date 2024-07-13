defmodule Stow.Adapter.Http.Httpc do
  @moduledoc false
  @behaviour Stow.Adapter

  import Stow.URI, only: [to_iolist: 1]
  import Stow.ResponseHandler

  alias Stow.Conn

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
  def dispatch(%Conn{method: :get} = conn) do
    with {http_opts, opts} <- split_options(conn.opts, {[], []}, conn.uri.scheme),
         headers <- maybe_to_charlist(conn.headers) do
      :httpc.request(:get, {to_iolist(conn.uri), headers}, http_opts, opts) |> to_response()
    end
  end

  def dispatch(_conn), do: {:error, :not_supported}

  defp split_options(nil, {http_opts, opts}, _), do: {http_opts, opts}
  defp split_options([], {http_opts, opts}, "http"), do: {http_opts, opts}
  defp split_options([], {http_opts, opts}, "https"), do: {http_opts |> set_ssl_opt(), opts}

  defp split_options([{k, v} | t], {http_opts, opts}, scheme) do
    case k in @http_options do
      true -> split_options(t, {[{k, v} | http_opts], opts}, scheme)
      false -> split_options(t, {http_opts, [{k, v} | opts]}, scheme)
    end
  end

  defp maybe_to_charlist([]), do: []
  defp maybe_to_charlist([{[k | _], _v}, _] = headers) when is_integer(k), do: headers

  defp maybe_to_charlist(headers) do
    Enum.map(headers, fn {k, v} -> {to_charlist(k), v} end)
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
