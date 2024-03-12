defmodule Stow.Plug.Uri do
  @moduledoc false

  @behaviour Plug

  alias Stow.Plug.Utils
  import Utils, only: [set_private_opts: 3]

  @impl true
  def init(opts), do: Keyword.validate!(opts, [:uri, :plug_type])

  @impl true
  def call(conn, opts) do
    with {:ok, _uri} <- uri(opts),
         {:ok, plug_type, opts} <- plug_type(opts),
         {:ok, conn} <- set_private_opts(conn, plug_type, opts) do
      conn
    else
      {:error, conn} -> conn
    end
  end

  defp uri(opts) do
    case Keyword.fetch!(opts, :uri) do
      uri when is_binary(uri) ->
        {:ok, URI.new!(uri)}

      %URI{} = uri ->
        {:ok, uri}
        # TODO: when uri is function
    end
  end

  defp plug_type(opts) do
    case Keyword.pop!(opts, :plug_type) do
      {type, opts} when type in [:sink, :source] -> {:ok, type, opts}
    end
  end
end
