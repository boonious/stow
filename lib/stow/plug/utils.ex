defmodule Stow.Plug.Utils do
  @moduledoc false

  alias Plug.Conn
  alias Stow.{Pipeline, Sink, Source}

  def fetch_uri(conn, opts, {plug_type, schemes}) when is_list(opts) do
    fetch_uri(conn, Keyword.get(opts, :uri, plug_type), schemes)
  end

  # opt1: uri from plug opts
  def fetch_uri(_conn, uri, schemes) when is_binary(uri) do
    URI.new(uri) |> check_scheme(schemes)
  end

  # opt2: uri from conn private
  def fetch_uri(conn, plug_type, schemes) when is_atom(plug_type) do
    get_in(conn.private, [Access.key(:stow), Access.key(plug_type)])
    |> priv_uri()
    |> check_scheme(schemes)
  end

  defp check_scheme({:ok, %URI{scheme: s} = uri}, schemes) do
    if s in schemes, do: {:ok, uri}, else: {:error, :einval}
  end

  defp check_scheme(_, _), do: {:error, :einval}

  defp priv_uri(%Sink{uri: uri, status: nil}) when is_binary(uri), do: URI.new(uri)
  defp priv_uri(%Source{uri: uri, status: nil}) when is_binary(uri), do: URI.new(uri)
  defp priv_uri(_), do: {:error, :einval}

  def set_uri_params(conn, %URI{} = uri) do
    %{
      conn
      | scheme: uri.scheme |> String.to_existing_atom(),
        host: uri.host,
        port: uri.port,
        request_path: uri.path || "",
        path_info: split_path(uri.path),
        query_string: uri.query || "",
        query_params: %Plug.Conn.Unfetched{aspect: :query_params}
    }
  end

  defp split_path(nil), do: []

  defp split_path(path) do
    segments = :binary.split(path, "/", [:global])
    for segment <- segments, segment != "", do: segment
  end

  def put_headers(conn, [], _), do: conn

  def put_headers(conn, [{k, v} | rest], type) when type in [:resp, :req] do
    apply(Conn, :"put_#{type}_header", [conn, k, v]) |> put_headers(rest, type)
  end

  def update_private(conn, _field, nil), do: conn

  def update_private(conn, field, value) when field in [:source, :sink] do
    case get_in(conn.private, [:stow]) do
      %Pipeline{} = stow -> put_in(stow, [Access.key!(field)], value)
      nil -> %Pipeline{} |> Map.put(field, value)
    end
    |> then(&Conn.put_private(conn, :stow, &1))
  end
end
