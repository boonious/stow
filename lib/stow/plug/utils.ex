defmodule Stow.Plug.Utils do
  @moduledoc false
  alias Stow.Sink

  def fetch_uri(conn, opts, schemes) when is_list(opts) do
    fetch_uri(conn, Keyword.get(opts, :uri), schemes)
  end

  # opt1: uri from plug opts
  def fetch_uri(_conn, uri, schemes) when is_binary(uri) do
    URI.new(uri) |> check_scheme(schemes)
  end

  # opt2: uri from conn private
  def fetch_uri(conn, nil, schemes) do
    conn.private[:stow][:sink]
    |> priv_uri()
    |> check_scheme(schemes)
  end

  defp check_scheme({:ok, %URI{scheme: s} = uri}, schemes) do
    if s in schemes, do: {:ok, uri}, else: {:error, :einval}
  end

  defp check_scheme(_, _), do: {:error, :einval}

  defp priv_uri(%Sink{uri: uri, status: nil}) when is_binary(uri), do: URI.new(uri)
  defp priv_uri(_), do: {:error, :einval}
end
