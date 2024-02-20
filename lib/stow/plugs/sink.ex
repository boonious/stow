defmodule Stow.Plugs.Sink do
  @moduledoc false
  @behaviour Plug

  alias Plug.Conn
  alias Stow.Sink
  alias Stow.Sinks

  import Plug.Conn, only: [put_private: 3]

  @supported_schemes ["file"]

  @impl true
  def init(opts), do: Keyword.validate!(opts, [:uri, :data])

  @impl true
  def call(conn, opts) do
    with {:ok, uri, conn} <- fetch_uri(conn, Keyword.get(opts, :uri)),
         {:ok, data} <- fetch_data(conn, Keyword.get(opts, :data)),
         {:ok, _uri, conn} <- put_data(conn, uri, data) do
      conn
    else
      {:error, conn} -> conn
    end
  end

  # opt1: uri from plug opts
  defp fetch_uri(conn, uri) when is_binary(uri) do
    URI.new(uri)
    |> check_scheme()
    |> update_conn(conn)
  end

  # opt2: uri from conn private
  defp fetch_uri(conn, nil) do
    conn.private[:stow][:sink]
    |> priv_uri()
    |> check_scheme()
    |> update_conn(conn)
  end

  defp check_scheme({:ok, %URI{scheme: s} = uri}) when s in @supported_schemes, do: {:ok, uri}
  defp check_scheme(_), do: {:error, :einval}

  defp priv_uri(%Sink{uri: uri, status: nil}) when is_binary(uri), do: URI.new(uri)
  defp priv_uri(_), do: {:error, :einval}

  # opt1: data from plug opts
  defp fetch_data(_conn, data) when is_binary(data) or is_list(data), do: {:ok, data}

  # opt2; data from conn resp body
  defp fetch_data(%Conn{resp_body: body, state: :set, status: 200}, nil) do
    {:ok, body}
  end

  defp fetch_data(conn, nil) do
    sink_data = %{conn.private[:stow][:sink] | status: {:error, :einval}}
    {:error, put_private(conn, :stow, %{sink: sink_data})}
  end

  defp put_data(conn, uri, data) do
    (uri.scheme <> "_sink")
    |> Macro.camelize()
    |> then(fn sink -> Module.concat(Sinks, sink) end)
    |> apply(:put, [uri, data, []])
    |> update_conn(conn, :ok)
  end

  defp update_conn(uri, conn, status \\ nil)

  defp update_conn({:ok, uri}, conn, nil) do
    {:ok, uri, put_private(conn, :stow, %{sink: Sink.new(uri |> to_string())})}
  end

  defp update_conn({:ok, uri}, conn, :ok) do
    {:ok, uri, put_private(conn, :stow, %{sink: Sink.done(uri |> to_string())})}
  end

  defp update_conn({:error, reason}, conn, _) do
    {:error, put_private(conn, :stow, %{sink: Sink.failed({:error, reason})})}
  end
end
