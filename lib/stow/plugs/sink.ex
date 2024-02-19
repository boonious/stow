defmodule Stow.Plugs.Sink do
  @moduledoc false
  @behaviour Plug

  alias Plug.Conn
  alias Stow.Sinks

  @impl true
  def init(opts), do: Keyword.validate!(opts, [:uri, :data])

  @impl true
  def call(conn, opts) do
    with {:ok, %URI{} = uri} <- fetch_uri(conn, opts),
         {:ok, data} <- fetch_data(conn, opts),
         {:ok, _uri} <- put_data(uri, data) do
      conn
    end
  end

  defp fetch_uri(conn, opts) do
    case Keyword.get(opts, :uri) do
      uri when is_binary(uri) -> URI.new(uri)
      nil -> private_uri(conn.private[:stow])
    end
  end

  defp private_uri(%{file_sink: %{uri: uri}}) when is_binary(uri), do: URI.new(uri)
  defp private_uri(nil), do: {:error, :einval}
  defp private_uri(_), do: {:error, :einval}

  defp fetch_data(conn, opts) do
    case Keyword.get(opts, :data) do
      data when is_binary(data) or is_list(data) -> {:ok, data}
      nil -> data_from_resp(conn)
    end
  end

  defp data_from_resp(%Conn{resp_body: body, state: :set}), do: {:ok, body}
  defp data_from_resp(_), do: {:error, :einval}

  defp put_data(uri, data) do
    (uri.scheme <> "_sink")
    |> Macro.camelize()
    |> then(fn sink -> Module.concat(Sinks, sink) end)
    |> apply(:put, [uri, data, []])
  end
end
