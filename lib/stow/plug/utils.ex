defmodule Stow.Plug.Utils do
  @moduledoc false

  alias Plug.Conn
  alias Stow.{Pipeline, Sink, Source}

  import Plug.Conn, only: [halt: 1, resp: 3]

  def fetch_uri(conn, opts, {field, schemes}) when is_list(opts) do
    fetch_uri(conn, field, schemes) |> update_status(conn, field)
  end

  # uri from conn private
  def fetch_uri(conn, field, schemes) when is_atom(field) do
    get_in(conn.private, [:stow, Access.key!(field)])
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

  def fetch_opts(options, plug_type, empty \\ %{})
  def fetch_opts(nil, _, empty), do: empty
  def fetch_opts(%{"file" => opts}, :sink, _) when is_list(opts), do: opts
  def fetch_opts(%{"http" => opts}, :source, _) when is_map(opts), do: opts

  def set_req_params(conn, %URI{} = uri) do
    with conn <- set_uri_params(conn, uri),
         req_headers <- fetch_headers(conn.private.stow.source.options, :req) do
      put_headers(conn, req_headers, :req)
    end
  end

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

  defp fetch_headers(nil, _type), do: []
  defp fetch_headers(%{"http" => %{req_headers: h}}, :req) when h != [], do: h
  defp fetch_headers(%{"http" => %{resp_headers: h}}, :resp) when h != [], do: h
  defp fetch_headers(%{}, _), do: []

  defp put_headers(conn, [], _), do: conn

  defp put_headers(conn, [{k, v} | rest], type) when type in [:resp, :req] do
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

  def set_private_opts(conn, plug_type, opts) do
    case {get_in(conn.private, [:stow, Access.key!(plug_type)]), plug_type} do
      {%Sink{} = _sink, _} ->
        {:ok, conn}

      {%Source{} = _sink, _} ->
        {:ok, conn}

      {nil, :sink} ->
        struct!(Sink, opts |> Keyword.drop([:data]))
        |> then(&{:ok, update_private(conn, plug_type, &1)})

      {nil, :source} ->
        struct!(Source, opts)
        |> then(&{:ok, update_private(conn, plug_type, &1)})
    end
  end

  def update_status({:ok, %URI{} = uri}, conn, _field), do: {:ok, uri, conn}

  def update_status({:ok, {200, headers, body}}, conn, field) do
    opts_headers = fetch_headers(conn.private.stow.source.options, :resp)

    conn
    |> resp(200, body)
    |> put_headers(headers ++ opts_headers, :resp)
    |> set_private_status(field, :ok)
    |> then(&{:ok, &1})
  end

  def update_status(:ok, conn, field), do: {:ok, conn |> set_private_status(field, :ok)}

  # error status

  def update_status({:ok, {non_200, headers, body}}, conn, field) do
    conn
    |> put_headers(headers, :resp)
    |> set_private_status(field, {:error, :non_200_status})
    |> resp(non_200, body)
    |> halt()
    |> then(&{:error, &1})
  end

  def update_status({:error, _} = error, conn, field) do
    conn
    |> set_private_status(field, error)
    |> halt()
    |> then(&{:error, &1})
  end

  defp set_private_status(conn, field, status) do
    update_private(
      conn,
      field,
      get_in(conn.private.stow, [Access.key!(field)]) |> Map.put(:status, status)
    )
  end
end
