defmodule Stow.Plug.Source do
  @moduledoc false
  @behaviour Plug

  alias Stow.Plug.Utils
  alias Stow.Source

  import Plug.Conn, only: [halt: 1, resp: 3]

  import Utils,
    only: [
      fetch_opts: 2,
      fetch_uri: 2,
      put_headers: 3,
      set_private_opts: 3,
      set_uri_params: 2,
      update_private: 3
    ]

  @plug_opts [:uri, :options]
  @schemes ["http", "https"]

  @impl true
  def init(opts), do: validate_opts(opts)

  @impl true
  def call(conn, opts) do
    with {:ok, conn} <- set_private_opts(conn, :source, opts),
         {:ok, uri, conn} <- parse_uri(conn, opts),
         conn <- set_uri_params(conn, uri),
         req_headers <- fetch_headers(conn.private.stow.source.options, :req),
         conn <- put_headers(conn, req_headers, :req),
         {:ok, conn} <- source_data(conn) do
      conn
    else
      {:error, conn} -> conn
    end
  end

  # TODO: validate options in %{"scheme" => keyword()} format
  defp validate_opts(opts), do: Keyword.validate!(opts, @plug_opts)

  defp parse_uri(conn, opts) do
    fetch_uri(conn, [field: :source, schemes: @schemes] |> Keyword.merge(opts))
    |> update_conn(conn)
  end

  # to fix: refactor this to the plug utils module
  defp fetch_headers(nil, _type), do: []
  defp fetch_headers(%{"http" => %{req_headers: h}}, :req) when h != [], do: h
  defp fetch_headers(%{"http" => %{resp_headers: h}}, :resp) when h != [], do: h
  defp fetch_headers(%{}, _), do: []

  defp source_data(conn) do
    normalise_scheme_name(conn.scheme)
    |> Kernel.<>("_source")
    |> Macro.camelize()
    |> then(fn source -> Module.concat(Source, source) end)
    |> apply(:get, [conn, fetch_opts(conn.private.stow.source.options, :source)])
    |> update_conn(conn)
  end

  defp normalise_scheme_name(scheme) when scheme in [:http, :https], do: "http"

  defp update_conn(resp, conn)
  defp update_conn({:ok, %URI{} = uri}, conn), do: {:ok, uri, conn}

  defp update_conn({:ok, {200, headers, body}}, conn) do
    opts_headers = fetch_headers(conn.private.stow.source.options, :resp)

    conn
    |> resp(200, body)
    |> put_headers(headers ++ opts_headers, :resp)
    |> update_private(:source, %{conn.private.stow.source | status: :ok})
    |> then(&{:ok, &1})
  end

  defp update_conn({:ok, {non_200_status, headers, body}}, conn) do
    error = {:error, :non_200_status}

    conn
    |> put_headers(headers, :resp)
    |> update_private(:source, %{conn.private.stow.source | status: error})
    |> resp(non_200_status, body)
    |> halt()
    |> then(&{:error, &1})
  end

  defp update_conn({:error, _} = error, conn) do
    conn
    |> update_private(:source, %{conn.private.stow.source | status: error})
    |> halt()
    |> then(&{:error, &1})
  end
end
