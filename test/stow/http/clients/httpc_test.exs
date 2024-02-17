defmodule Stow.Http.Clients.HttpcTest do
  use ExUnit.Case, async: true

  import Stow.Http.Client, only: [build_req_url: 1]
  alias Plug.Conn
  alias Stow.Http.Clients.Httpc

  setup do
    bypass = Bypass.open()

    %{
      bypass: bypass,
      conn: %Conn{
        method: "GET",
        scheme: :http,
        host: "localhost",
        request_path: "/request/path",
        query_string: "foo=bar",
        port: bypass.port
      },
      options: [timeout: 5_000, connect_timeout: 5_000, sync: true, body_format: :string]
    }
  end

  describe "dispatch/2 GET" do
    test "url with request path and query string", %{bypass: bypass, conn: conn, options: opts} do
      Bypass.expect(bypass, fn conn ->
        request_url = build_req_url(conn) |> to_string()
        assert request_url == "http://localhost:#{bypass.port}/request/path?foo=bar"
        assert conn.method == "GET"

        Plug.Conn.resp(conn, 200, "getting a response")
      end)

      assert {:ok, {status, headers, body}} = conn |> Httpc.dispatch(opts)
      assert status == {~c"HTTP/1.1", 200, ~c"OK"}
      assert {~c"server", ~c"Cowboy"} in headers
      assert body == ~c"getting a response"
    end

    test "url without request path and query string ", %{bypass: bypass, conn: conn} do
      Bypass.expect(bypass, fn conn ->
        request_url = build_req_url(conn) |> to_string()
        assert request_url == "http://localhost:#{bypass.port}/"
        assert conn.method == "GET"

        Plug.Conn.resp(conn, 200, "getting a response")
      end)

      conn = %{conn | query_string: "", request_path: ""}
      assert {:ok, {status, _headers, body}} = conn |> Httpc.dispatch([])
      assert status == {~c"HTTP/1.1", 200, ~c"OK"}
      assert body == ~c"getting a response"
    end

    test "url without query string ", %{bypass: bypass, conn: conn} do
      Bypass.expect(bypass, fn conn ->
        request_url = build_req_url(conn) |> to_string()
        assert request_url == "http://localhost:#{bypass.port}/request/path"
        assert conn.method == "GET"

        Plug.Conn.resp(conn, 200, "getting a response")
      end)

      conn = %{conn | query_string: ""}
      assert {:ok, {status, _headers, body}} = conn |> Httpc.dispatch([])
      assert status == {~c"HTTP/1.1", 200, ~c"OK"}
      assert body == ~c"getting a response"
    end
  end

  test "dispatch/2 http methods to be implemented", %{conn: conn} do
    conn = %{conn | method: "DELETE"}
    assert {:error, :not_supported} = conn |> Httpc.dispatch([])
  end
end
