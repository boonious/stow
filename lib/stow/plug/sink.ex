defmodule Stow.Plug.Sink do
  @moduledoc false
  @behaviour Plug

  alias Plug.Conn
  alias Stow.Sink
  alias Stow.Plug.Utils

  import Utils, only: [fetch_opts: 3, fetch_uri: 2, set_private_opts: 3, update_private: 3]

  @plug_opts [:uri, :data, :options]
  @schemes ["file"]

  @impl true
  def init(opts), do: validate_opts(opts)

  @impl true
  def call(conn, opts) do
    with {:ok, conn} <- set_private_opts(conn, :sink, opts),
         {:ok, uri, conn} <- parse_uri(conn, opts),
         {:ok, data} <- fetch_data(conn, Keyword.get(opts, :data)),
         {:ok, _uri, conn} <- put_data(conn, uri, data) do
      conn
    else
      {:error, conn} -> conn
    end
  end

  # TODO: validate options in %{"scheme" => keyword()} format
  defp validate_opts(opts), do: Keyword.validate!(opts, @plug_opts)

  defp parse_uri(conn, opts) do
    fetch_uri(conn, [field: :sink, schemes: @schemes] |> Keyword.merge(opts)) |> update_conn(conn)
  end

  # opt1: data from plug opts
  defp fetch_data(_conn, data) when is_binary(data) or is_list(data), do: {:ok, data}

  # opt2; data from conn resp body
  defp fetch_data(%Conn{resp_body: body, state: :set, status: 200}, nil) do
    {:ok, body}
  end

  defp fetch_data(conn, nil) do
    {:error, update_private(conn, :sink, %{conn.private.stow.sink | status: {:error, :einval}})}
  end

  defp put_data(conn, uri, data) do
    (uri.scheme <> "_sink")
    |> Macro.camelize()
    |> then(fn sink -> Module.concat(Sink, sink) end)
    |> apply(:put, [uri, data, fetch_opts(conn.private.stow.sink.options, :sink, [])])
    |> update_conn(conn, :ok)
  end

  defp update_conn(uri, conn, status \\ nil)

  defp update_conn({:ok, uri}, conn, nil), do: {:ok, uri, conn}

  defp update_conn({:ok, uri}, conn, :ok) do
    {:ok, uri, update_private(conn, :sink, %{conn.private.stow.sink | status: :ok})}
  end

  defp update_conn({:error, reason}, conn, _) do
    {:error, update_private(conn, :sink, %{conn.private.stow.sink | status: {:error, reason}})}
  end
end
