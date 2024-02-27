defmodule Stow.Plug.SourceTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Plug.Conn

  alias Stow.Http.ClientMock, as: HttpClient
  alias Stow.Plug.Source
  alias Stow.Source, as: SourceStruct

  import Hammox
  import Stow.Plug.Utils, only: [update_private: 3]

  defmodule HttpSourceTestPlug do
    use Plug.Builder

    plug(Source,
      uri: "http://localhost/path/to/source?foo=bar",
      req_headers: [{"accept", "text/html"}, {"accept-charset", "utf-8"}],
      resp_headers: [{"server", "apache/2.4.1 (unix)"}, {"cache-control", "max-age=604800"}]
    )
  end

  setup :verify_on_exit!

  describe "http source" do
    setup do
      {status, headers, body} = {200, [{"content-type", "text/html; charset=utf-8"}], "hi"}

      %{
        conn: conn(:get, "/"),
        resp: {:ok, {status, headers, body}},
        uri: "http://localhost/path/to/source?foo=bar",
        req_headers: [{"accept", "text/html"}, {"accept-charset", "utf-8"}],
        resp_headers: [{"server", "apache/2.4.1 (unix)"}, {"cache-control", "max-age=604800"}]
      }
    end

    test "via compile plug opts", %{conn: conn, uri: uri} = context do
      expect(HttpClient, :dispatch, fn conn, [] ->
        for h <- context.req_headers, do: assert(h in conn.req_headers)
        context.resp
      end)

      assert %Conn{} = conn = __MODULE__.HttpSourceTestPlug.call(conn, [])
      assert %SourceStruct{uri: ^uri, status: :ok} = conn.private.stow.source
      for h <- context.resp_headers, do: assert(h in conn.resp_headers)
    end

    test "via runtime plug opts", %{conn: conn, uri: uri} = context do
      expect(HttpClient, :dispatch, fn conn, [] ->
        for h <- context.req_headers, do: assert(h in conn.req_headers)
        context.resp
      end)

      conn =
        Source.call(conn,
          uri: uri,
          req_headers: context.req_headers,
          resp_headers: context.resp_headers
        )

      assert %Conn{} = conn
      assert %SourceStruct{uri: ^uri, status: :ok} = conn.private.stow.source
      for h <- context.resp_headers, do: assert(h in conn.resp_headers)
    end

    test "via connection private params", %{conn: conn, uri: uri} = context do
      expect(HttpClient, :dispatch, fn conn, [] ->
        for h <- context.req_headers, do: assert(h in conn.req_headers)
        context.resp
      end)

      conn =
        update_private(
          conn,
          :source,
          SourceStruct.new(uri,
            req_headers: context.req_headers,
            resp_headers: context.resp_headers
          )
        )

      assert %Conn{} = conn = Source.call(conn, [])
      assert %SourceStruct{uri: ^uri, status: :ok} = conn.private.stow.source
      for h <- context.resp_headers, do: assert(h in conn.resp_headers)
    end

    test "client request uri and query params", %{conn: conn, resp: resp, uri: uri} do
      %{scheme: scheme, host: host, path: path, port: port, query: query} = URI.new!(uri)

      HttpClient
      |> expect(:dispatch, fn conn, [] ->
        assert %Conn{host: ^host, request_path: ^path, port: ^port, query_string: ^query} = conn
        assert conn.method == "GET"
        assert conn.scheme |> to_string() == scheme

        resp
      end)

      Source.call(conn, uri: uri)
    end

    test "return conn with source uri params", %{conn: conn, resp: resp, uri: uri} do
      %{scheme: scheme, host: host, path: path, port: port, query: query} = URI.new!(uri)
      HttpClient |> expect(:dispatch, fn _conn, [] -> resp end)

      assert %Conn{} = conn = Source.call(conn, uri: uri)
      assert %Conn{host: ^host, request_path: ^path, port: ^port, query_string: ^query} = conn
      assert conn.method == "GET"
      assert conn.scheme |> to_string() == scheme
    end

    test "return conn with source http response", %{conn: conn, resp: resp, uri: uri} do
      {:ok, {status, [header], body}} = resp
      HttpClient |> expect(:dispatch, fn _conn, [] -> resp end)

      assert %Conn{} = conn = Source.call(conn, uri: uri)
      assert %Conn{resp_body: ^body, status: ^status} = conn
      assert header in conn.resp_headers
    end

    test "return conn with :set state", %{conn: conn, resp: resp, uri: uri} do
      HttpClient |> expect(:dispatch, fn _conn, [] -> resp end)

      assert %Conn{} = conn = Source.call(conn, uri: uri)
      assert conn.state == :set
    end

    test "when source response is non 200", %{conn: conn, uri: uri} do
      HttpClient
      |> expect(:dispatch, fn _conn, [] -> {:ok, {500, [], "Internal Server Error"}} end)

      assert %Conn{halted: true} = conn = Source.call(conn, uri: uri)
      assert %SourceStruct{uri: ^uri, status: {:error, :"500_status"}} = conn.private.stow.source
    end

    test "when source is down", %{conn: conn, uri: uri} do
      HttpClient |> expect(:dispatch, fn _conn, [] -> {:error, :econnrefused} end)

      assert %Conn{halted: true} = conn = Source.call(conn, uri: uri)
      assert %SourceStruct{uri: ^uri, status: {:error, :econnrefused}} = conn.private.stow.source
      assert conn.state != :set
    end

    test "error status on malformed http uri", %{conn: conn} do
      assert %Conn{halted: true} = conn = Source.call(conn, uri: "file:/not/http/source")
      assert %SourceStruct{uri: nil, status: {:error, :einval}} = conn.private.stow.source

      conn = update_private(conn, :source, SourceStruct.new("file:/not/http/source"))
      assert %Conn{halted: true} = conn = Source.call(conn, [])
      assert %SourceStruct{uri: nil, status: {:error, :einval}} = conn.private.stow.source
      assert conn.state != :set
    end

    test "error status when no http uri available", %{conn: conn} do
      assert %Conn{halted: true} = conn = Source.call(conn, [])
      assert %SourceStruct{uri: nil, status: {:error, :einval}} = conn.private.stow.source
      assert conn.state != :set
    end
  end
end
