defmodule Stow.Plug.Source do
  @moduledoc false
  @behaviour Plug

  alias Stow.Plug.Utils
  alias Stow.Source

  import Plug.Conn, only: [halt: 1, resp: 3]
  import Utils, only: [fetch_uri: 2, put_headers: 3, set_uri_params: 2, update_private: 3]

  @plug_opts [:uri, :extras]
  @schemes ["http", "https"]

  @impl true
  def init(opts), do: validate_opts(opts)

  @impl true
  def call(conn, opts) do
    with opts <- validate_opts(opts),
         {:ok, uri, conn} <- parse_uri(conn, opts),
         conn <- set_uri_params(conn, uri),
         req_headers <- get_req_headers(conn, opts),
         conn <- put_headers(conn, req_headers, :req),
         {:ok, _uri, conn} <- source_data(conn, uri, opts) do
      conn
    else
      {:error, conn} -> conn
    end
  end

  defp validate_opts(opts), do: Keyword.validate!(opts, @plug_opts)

  defp parse_uri(conn, opts) do
    fetch_uri(conn, [field: :source, schemes: @schemes] |> Keyword.merge(opts))
    |> update_conn(conn)
  end

  defp get_req_headers(conn, opts) do
    fetch_headers(conn.private.stow.source, :req) ||
      fetch_headers(Keyword.get(opts, :extras), :req) || []
  end

  # to fix: refactor this to the plug utils module
  defp fetch_headers(nil, _type), do: nil
  defp fetch_headers(%Source{extras: %{headers: %{req: h}}}, :req) when h != [], do: h
  defp fetch_headers(%Source{extras: %{headers: %{resp: h}}}, :resp) when h != [], do: h
  defp fetch_headers(%{headers: %{req: h}}, :req) when h != [], do: h
  defp fetch_headers(%{headers: %{resp: h}}, :resp) when h != [], do: h
  defp fetch_headers(%{}, _), do: nil

  defp source_data(conn, uri, opts) do
    normalise_scheme_name(conn.scheme)
    |> Kernel.<>("_source")
    |> Macro.camelize()
    |> then(fn source -> Module.concat(Source, source) end)
    |> apply(:get, [conn, opts |> Keyword.drop(@plug_opts)])
    |> update_conn(conn, uri, fetch_headers(Keyword.get(opts, :extras), :resp) || [])
  end

  defp normalise_scheme_name(scheme) when scheme in [:http, :https], do: "http"

  defp update_conn(resp, conn)

  defp update_conn({:ok, %URI{} = uri}, conn) do
    source = get_in(conn.private, [:stow, Access.key!(:source)])

    headers = [
      req_headers: fetch_headers(source, :req) || [],
      resp_headers: fetch_headers(source, :resp) || []
    ]

    {:ok, uri, update_private(conn, :source, Source.new(uri |> to_string(), headers))}
  end

  defp update_conn({:error, reason}, conn) do
    {:error, update_private(conn, :source, Source.failed({:error, reason})) |> halt()}
  end

  defp update_conn({:ok, {200, headers, body}}, conn, uri, resp_headers) do
    opts_headers = fetch_headers(conn.private.stow.source, :resp) || resp_headers

    conn
    |> resp(200, body)
    |> put_headers(headers ++ opts_headers, :resp)
    |> update_private(:source, Source.done(uri |> to_string()))
    |> then(fn conn -> {:ok, uri, conn} end)
  end

  defp update_conn({:ok, {non_200_status, headers, body}}, conn, uri, opt_headers) do
    error = {:error, :"#{inspect(non_200_status)}_status"}

    conn
    |> put_headers(headers ++ opt_headers, :resp)
    |> update_private(:source, Source.failed(error, uri |> to_string()))
    |> resp(non_200_status, body)
    |> halt()
    |> then(fn conn -> {:error, conn} end)
  end

  defp update_conn({:error, _} = err, conn, uri, _opt_headers) do
    conn
    |> update_private(:source, Source.failed(err, uri |> to_string()))
    |> halt()
    |> then(fn conn -> {:error, conn} end)
  end
end
