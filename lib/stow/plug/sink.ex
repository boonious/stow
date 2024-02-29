defmodule Stow.Plug.Sink do
  @moduledoc false
  @behaviour Plug

  alias Plug.Conn
  alias Stow.Sink
  alias Stow.Plug.Utils

  import Utils, only: [fetch_uri: 2, update_private: 3]

  @plug_opts [:uri, :data, :extra_opts]
  @schemes ["file"]

  @impl true
  def init(opts), do: validate_opts(opts)

  @impl true
  def call(conn, opts) do
    with opts <- validate_opts(opts),
         {:ok, uri, conn} <- parse_uri(conn, opts),
         {:ok, data} <- fetch_data(conn, Keyword.get(opts, :data)),
         {:ok, _uri, conn} <- put_data(conn, uri, data, opts) do
      conn
    else
      {:error, conn} -> conn
    end
  end

  defp validate_opts(opts), do: Keyword.validate!(opts, @plug_opts)
  defp add_extra_opts(opts), do: [field: :sink, schemes: @schemes] |> Keyword.merge(opts)

  defp parse_uri(conn, opts),
    do: add_extra_opts(opts) |> then(&fetch_uri(conn, &1)) |> update_conn(conn)

  # opt1: data from plug opts
  defp fetch_data(_conn, data) when is_binary(data) or is_list(data), do: {:ok, data}

  # opt2; data from conn resp body
  defp fetch_data(%Conn{resp_body: body, state: :set, status: 200}, nil) do
    {:ok, body}
  end

  defp fetch_data(conn, nil) do
    {:error, update_private(conn, :sink, %{conn.private.stow.sink | status: {:error, :einval}})}
  end

  defp put_data(conn, uri, data, opts) do
    (uri.scheme <> "_sink")
    |> Macro.camelize()
    |> then(fn sink -> Module.concat(Sink, sink) end)
    |> apply(:put, [uri, data, Keyword.get(opts, :extra_opts, [])])
    |> update_conn(conn, :ok)
  end

  defp update_conn(uri, conn, status \\ nil)

  defp update_conn({:ok, uri}, conn, nil) do
    {:ok, uri, update_private(conn, :sink, Sink.new(uri |> to_string()))}
  end

  defp update_conn({:ok, uri}, conn, :ok) do
    {:ok, uri, update_private(conn, :sink, Sink.done(uri |> to_string()))}
  end

  defp update_conn({:error, reason}, conn, _) do
    {:error, update_private(conn, :sink, Sink.failed({:error, reason}))}
  end
end
