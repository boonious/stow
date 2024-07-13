defmodule Stow.Adapter.Http.HttpcTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureLog

  alias Stow.Adapter.Http.Httpc
  alias Stow.Conn
  alias Stow.Response

  setup do
    bypass = Bypass.open()

    uri = %Stow.URI{
      host: "localhost",
      path: "/request/path",
      scheme: "http",
      port: bypass.port,
      query: "foo=bar"
    }

    opts = [timeout: 5_000, connect_timeout: 5_000, sync: true, body_format: :string]

    %{
      bypass: bypass,
      uri: uri,
      conn: %Conn{method: :get, uri: uri},
      opts: opts
    }
  end

  defp assert_ok_response(response) do
    assert %Response{} = response
    assert {"server", "Cowboy"} in response.headers
    assert response.status == 200
    assert response.body == "getting a response"
    assert response.state == :ok
  end

  describe "dispatch/1" do
    test "request path and query string", %{bypass: bypass, conn: conn} do
      Bypass.expect(bypass, fn conn ->
        request_url = Plug.Conn.request_url(conn)
        assert request_url == "http://localhost:#{bypass.port}/request/path?foo=bar"
        assert conn.method == "GET"

        Plug.Conn.resp(conn, 200, "getting a response")
      end)

      conn |> Httpc.dispatch() |> assert_ok_response()
    end

    test "without request path and query string ", %{bypass: bypass, conn: conn, uri: uri} do
      Bypass.expect(bypass, fn conn ->
        request_url = Plug.Conn.request_url(conn)
        assert request_url == "http://localhost:#{bypass.port}/"
        assert conn.method == "GET"

        Plug.Conn.resp(conn, 200, "getting a response")
      end)

      uri = %{uri | query: "", path: ""}
      %{conn | uri: uri} |> Httpc.dispatch() |> assert_ok_response()
    end

    test "without query string ", %{bypass: bypass, conn: conn, uri: uri} do
      Bypass.expect(bypass, fn conn ->
        request_url = Plug.Conn.request_url(conn)
        assert request_url == "http://localhost:#{bypass.port}/request/path"
        assert conn.method == "GET"

        Plug.Conn.resp(conn, 200, "getting a response")
      end)

      uri = %{uri | query: ""}
      %{conn | uri: uri} |> Httpc.dispatch() |> assert_ok_response()
    end

    test "in https scheme", %{conn: conn, opts: opts, uri: uri} do
      uri = %{uri | scheme: "https"}
      conn = %{conn | uri: uri, opts: opts}
      # Bypass doesn't support https/ssl, need to find alternative
      # to complete this test
      # Bypass.expect(bypass, fn conn -> Plug.Conn.resp(conn, 200, "getting a response") end)

      # emits error atm.
      capture_log(fn -> conn |> Httpc.dispatch() end)
    end

    test "with options", %{bypass: bypass, conn: conn, opts: opts} do
      conn = %{conn | opts: opts}

      Bypass.expect(bypass, fn conn -> Plug.Conn.resp(conn, 200, "getting a response") end)
      conn |> Httpc.dispatch() |> assert_ok_response()
    end

    test "with charlist (native) request headers", %{bypass: bypass, conn: conn} do
      req_headers = [
        {~c"accept", ~c"application/json,text/html"},
        {~c"accept-Language", ~c"en-US,en;q=0.5"}
      ]

      Bypass.expect(bypass, fn conn ->
        assert {"accept", "application/json,text/html"} in conn.req_headers
        assert {"accept-language", "en-US,en;q=0.5"} in conn.req_headers

        Plug.Conn.resp(conn, 200, "getting a response")
      end)

      %{conn | headers: req_headers} |> Httpc.dispatch() |> assert_ok_response()
    end

    test "with binary request headers", %{bypass: bypass, conn: conn} do
      req_headers = [
        {"accept", "application/json,text/html"},
        {"accept-Language", "en-US,en;q=0.5"}
      ]

      Bypass.expect(bypass, fn conn ->
        assert {"accept", "application/json,text/html"} in conn.req_headers
        assert {"accept-language", "en-US,en;q=0.5"} in conn.req_headers

        Plug.Conn.resp(conn, 200, "getting a response")
      end)

      %{conn | headers: req_headers} |> Httpc.dispatch() |> assert_ok_response()
    end

    test "returns error on invalid headers", %{conn: conn} do
      req_headers = [
        {~c"accept", ~c"application/json,text/html"},
        {"accept-Language", "en-US,en;q=0.5"}
      ]

      assert %Response{} = response = %{conn | headers: req_headers} |> Httpc.dispatch()
      assert response.state == {:error, {:headers_error, :invalid_field}}
    end
  end

  test "dispatch/1 other http methods yet to be implemented", %{conn: conn} do
    conn = %{conn | method: :delete}
    assert {:error, :not_supported} = conn |> Httpc.dispatch()
  end
end
