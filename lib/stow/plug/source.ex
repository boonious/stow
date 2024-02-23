defmodule Stow.Plug.Source do
  @moduledoc false
  @behaviour Plug

  alias Stow.Plug.Utils
  alias Stow.Source

  import Plug.Conn, only: [halt: 1, put_private: 3, resp: 3]

  @plug_opts [:uri, :req_headers, :resp_headers]
  @schemes ["http", "https"]

  @impl true
  def init(opts), do: Keyword.validate!(opts, @plug_opts)

  @impl true
  def call(conn, opts) do
    with {:ok, uri, conn} <- fetch_uri(conn, opts),
         conn <- set_uri_params(conn, uri),
         req_headers <- get_req_headers(conn, opts),
         conn <- put_headers(conn, req_headers, :req),
         {:ok, _uri, conn} <- source_data(conn, uri, opts) do
      conn
    else
      {:error, conn} -> conn
    end
  end

  defp fetch_uri(conn, opts) do
    Utils.fetch_uri(conn, opts, {:source, @schemes}) |> update_conn(conn)
  end

  defdelegate set_uri_params(conn, uri), to: Utils
  defdelegate put_headers(conn, headers, type), to: Utils

  defp get_req_headers(conn, opts) do
    private_headers(conn.private[:stow][:source], :req) || Keyword.get(opts, :req_headers, [])
  end

  defp private_headers(nil, _type), do: nil
  defp private_headers(%Source{req_headers: h}, :req) when h != [], do: h
  defp private_headers(%Source{resp_headers: h}, :resp) when h != [], do: h
  defp private_headers(%Source{}, _), do: nil

  defp source_data(conn, uri, opts) do
    normalise_scheme_name(conn.scheme)
    |> Kernel.<>("_source")
    |> Macro.camelize()
    |> then(fn source -> Module.concat(Source, source) end)
    |> apply(:get, [conn, opts |> Keyword.drop(@plug_opts)])
    |> update_conn(conn, uri, Keyword.get(opts, :resp_headers, []))
  end

  defp normalise_scheme_name(scheme) when scheme in [:http, :https], do: "http"

  defp update_conn(resp, conn)

  defp update_conn({:ok, %URI{} = uri}, conn) do
    headers = [
      req_headers: private_headers(conn.private[:stow][:source], :req) || [],
      resp_headers: private_headers(conn.private[:stow][:source], :resp) || []
    ]

    {:ok, uri, put_private(conn, :stow, %{source: Source.new(uri |> to_string(), headers)})}
  end

  defp update_conn({:error, reason}, conn) do
    {:error, put_private(conn, :stow, %{source: Source.failed({:error, reason})}) |> halt()}
  end

  defp update_conn({:ok, {200, headers, body}}, conn, uri, resp_headers) do
    private_headers = private_headers(conn.private[:stow][:source], :resp)
    opts_headers = private_headers || resp_headers

    conn
    |> resp(200, body)
    |> put_headers(headers ++ opts_headers, :resp)
    |> put_private(:stow, %{source: Source.done(uri |> to_string())})
    |> then(fn conn -> {:ok, uri, conn} end)
  end

  defp update_conn({:ok, {non_200_status, headers, body}}, conn, uri, opt_headers) do
    error = {:error, :"#{non_200_status}_status"}

    conn
    |> put_headers(headers ++ opt_headers, :resp)
    |> put_private(:stow, %{source: Source.failed(error, uri |> to_string())})
    |> resp(non_200_status, body)
    |> halt()
    |> then(fn conn -> {:error, conn} end)
  end

  defp update_conn({:error, _} = err, conn, uri, _opt_headers) do
    conn
    |> put_private(:stow, %{source: Source.failed(err, uri |> to_string())})
    |> halt()
    |> then(fn conn -> {:error, conn} end)
  end
end
