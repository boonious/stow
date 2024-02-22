defmodule Stow.Plug.Source do
  @moduledoc false
  @behaviour Plug

  alias Stow.Plug.Utils
  alias Stow.Source

  import Plug.Conn, only: [halt: 1, put_private: 3, put_resp_header: 3, resp: 3]

  @schemes ["http", "https"]
  @plug_opts [:uri]

  @impl true
  def init(opts), do: Keyword.validate!(opts, @plug_opts)

  @impl true
  def call(conn, opts) do
    with {:ok, uri, conn} <- fetch_uri(conn, opts),
         conn <- Utils.set_uri_params(conn, uri),
         {:ok, _uri, conn} <- source_data(conn, uri, opts) do
      conn
    else
      {:error, conn} -> conn
    end
  end

  defp fetch_uri(conn, opts) do
    Utils.fetch_uri(conn, opts, {:source, @schemes}) |> update_conn(conn)
  end

  defp source_data(conn, uri, opts) do
    normalise_scheme_name(conn.scheme)
    |> Kernel.<>("_source")
    |> Macro.camelize()
    |> then(fn source -> Module.concat(Source, source) end)
    |> apply(:get, [conn, opts |> Keyword.drop(@plug_opts)])
    |> update_conn(conn, uri)
  end

  defp normalise_scheme_name(scheme) when scheme in [:http, :https], do: "http"

  defp update_conn(resp, conn)

  defp update_conn({:ok, %URI{} = uri}, conn) do
    {:ok, uri, put_private(conn, :stow, %{source: Source.new(uri |> to_string())})}
  end

  defp update_conn({:error, reason}, conn) do
    {:error, put_private(conn, :stow, %{source: Source.failed({:error, reason})}) |> halt()}
  end

  defp update_conn({:ok, {200, headers, body}}, conn, uri) do
    conn
    |> put_headers(headers)
    |> put_private(:stow, %{source: Source.done(uri |> to_string())})
    |> resp(200, body)
    |> then(fn conn -> {:ok, uri, conn} end)
  end

  defp update_conn({:ok, {non_200_status, headers, body}}, conn, uri) do
    error = {:error, :"#{non_200_status}_status"}

    conn
    |> put_headers(headers)
    |> put_private(:stow, %{source: Source.failed(error, uri |> to_string())})
    |> resp(non_200_status, body)
    |> halt()
    |> then(fn conn -> {:error, conn} end)
  end

  defp update_conn({:error, _} = err, conn, uri) do
    conn
    |> put_private(:stow, %{source: Source.failed(err, uri |> to_string())})
    |> halt()
    |> then(fn conn -> {:error, conn} end)
  end

  defp put_headers(conn, []), do: conn

  defp put_headers(conn, [{k, v} | rest]) do
    put_headers(conn |> put_resp_header(k, v), rest)
  end
end
