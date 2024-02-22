defmodule Stow.Plug.UtilsTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Stow.Plug.Utils

  test "set_uri_params/2" do
    conn = conn(:get, "")

    uri = "https://localhost/path/to/source?foo=bar" |> URI.new!()
    conn = Utils.set_uri_params(conn, uri)
    assert_conn_params(conn, uri)

    uri = "http://localhost" |> URI.new!()
    conn = Utils.set_uri_params(conn, uri)
    assert_conn_params(conn, uri)

    uri = "http:///path" |> URI.new!()
    conn = Utils.set_uri_params(conn, uri)
    assert_conn_params(conn, uri)

    uri = "https://localhost:2020/path/to" |> URI.new!()
    conn = Utils.set_uri_params(conn, uri)
    assert_conn_params(conn, uri)
  end

  defp assert_conn_params(conn, uri) do
    assert conn.scheme |> to_string() == uri.scheme
    assert conn.host == uri.host
    assert conn.port == uri.port
    assert conn.request_path == uri.path || ""
    assert conn.query_string |> to_string() == uri.query || ""

    assert conn.path_info ==
             if(uri.path, do: uri.path |> String.split("/") |> List.delete(""), else: [])
  end
end
