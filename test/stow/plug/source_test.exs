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
      options: %{
        "http" => %{
          req_headers: [{"accept", "text/html"}, {"accept-charset", "utf-8"}],
          resp_headers: [{"server", "apache/2.4.1 (unix)"}, {"cache-control", "max-age=604800"}]
        }
      }
    )
  end

  setup :verify_on_exit!

  setup_all do
    {status, headers, body} = {200, [{"content-type", "text/html; charset=utf-8"}], "hi"}

    %{
      conn: conn(:get, "/"),
      resp: {:ok, {status, headers, body}},
      uri: "http://localhost/path/to/source?foo=bar",
      req_headers: [{"accept", "text/html"}, {"accept-charset", "utf-8"}],
      resp_headers: [{"server", "apache/2.4.1 (unix)"}, {"cache-control", "max-age=604800"}]
    }
  end

  describe "http source" do
    test "via compile plug opts", %{conn: conn, uri: uri} = context do
      expect(HttpClient, :dispatch, fn conn, [] ->
        for h <- context.req_headers, do: assert(h in conn.req_headers)
        context.resp
      end)

      opts = Source.init([])
      assert %Conn{} = conn = __MODULE__.HttpSourceTestPlug.call(conn, opts)
      assert %SourceStruct{uri: ^uri, status: :ok} = conn.private.stow.source
      for h <- context.resp_headers, do: assert(h in conn.resp_headers)
    end

    test "via runtime plug opts", %{conn: conn, uri: uri} = context do
      expect(HttpClient, :dispatch, fn conn, [] ->
        for h <- context.req_headers, do: assert(h in conn.req_headers)
        context.resp
      end)

      opts =
        Source.init(
          uri: uri,
          options: %{
            "http" => %{
              req_headers: context.req_headers,
              resp_headers: context.resp_headers
            }
          }
        )

      assert %Conn{} = conn = Source.call(conn, opts)
      assert %SourceStruct{uri: ^uri, status: :ok} = conn.private.stow.source
      for h <- context.resp_headers, do: assert(h in conn.resp_headers)
    end

    test "via connection private params", %{conn: conn, uri: uri} = context do
      expect(HttpClient, :dispatch, fn conn, [] ->
        for h <- context.req_headers, do: assert(h in conn.req_headers)
        context.resp
      end)

      options = %{
        "http" => %{req_headers: context.req_headers, resp_headers: context.resp_headers}
      }

      conn = update_private(conn, :source, SourceStruct.new(uri, options))

      assert %Conn{} = conn = Source.call(conn, Source.init([]))
      assert %SourceStruct{uri: ^uri, status: :ok, options: ^options} = conn.private.stow.source
      for h <- context.resp_headers, do: assert(h in conn.resp_headers)
    end

    # TODO: test passing of http opts to underlying client

    test "client request uri and query params", %{conn: conn, resp: resp, uri: uri} do
      %{scheme: scheme, host: host, path: path, port: port, query: query} = URI.new!(uri)

      HttpClient
      |> expect(:dispatch, fn conn, [] ->
        assert %Conn{host: ^host, request_path: ^path, port: ^port, query_string: ^query} = conn
        assert conn.method == "GET"
        assert conn.scheme |> to_string() == scheme

        resp
      end)

      Source.call(conn, Source.init(uri: uri))
    end

    test "return conn with source uri params", %{conn: conn, resp: resp, uri: uri} do
      %{scheme: scheme, host: host, path: path, port: port, query: query} = URI.new!(uri)
      HttpClient |> expect(:dispatch, fn _conn, [] -> resp end)

      assert %Conn{} = conn = Source.call(conn, Source.init(uri: uri))
      assert %Conn{host: ^host, request_path: ^path, port: ^port, query_string: ^query} = conn
      assert conn.method == "GET"
      assert conn.scheme |> to_string() == scheme
      assert conn.halted == false
    end

    test "return conn with source http response", %{conn: conn, resp: resp, uri: uri} do
      {:ok, {status, [header], body}} = resp
      HttpClient |> expect(:dispatch, fn _conn, [] -> resp end)

      assert %Conn{} = conn = Source.call(conn, Source.init(uri: uri))
      assert %Conn{resp_body: ^body, status: ^status} = conn
      assert header in conn.resp_headers
      assert conn.halted == false
    end

    test "return conn with :set state", %{conn: conn, resp: resp, uri: uri} do
      HttpClient |> expect(:dispatch, fn _conn, [] -> resp end)

      assert %Conn{} = conn = Source.call(conn, Source.init(uri: uri))
      assert conn.state == :set
      assert conn.halted == false
    end

    test "when source response is non 200", %{conn: conn, uri: uri} do
      HttpClient
      |> expect(:dispatch, fn _conn, [] -> {:ok, {500, [], "Internal Server Error"}} end)

      assert %Conn{halted: true} = conn = Source.call(conn, Source.init(uri: uri))
      assert conn.state == :set

      assert %SourceStruct{uri: ^uri, status: {:error, :non_200_status}} =
               conn.private.stow.source
    end

    test "error and halted status when source is down", %{conn: conn, uri: uri} do
      HttpClient |> expect(:dispatch, fn _conn, [] -> {:error, :econnrefused} end)

      assert %Conn{halted: true} = conn_resp = Source.call(conn, Source.init(uri: uri))

      assert %SourceStruct{uri: ^uri, status: {:error, :econnrefused}} =
               conn_resp.private.stow.source

      assert conn_resp.state != :set
      assert conn_resp.halted == true
    end

    test "error and halted status on unsupported source", %{conn: conn} do
      uri = "file:/not/http/source"
      assert %Conn{halted: true} = conn_resp = Source.call(conn, Source.init(uri: uri))
      assert %SourceStruct{uri: ^uri, status: {:error, :einval}} = conn_resp.private.stow.source
      assert conn_resp.halted == true

      conn = update_private(conn, :source, SourceStruct.new(uri))
      assert %Conn{halted: true} = conn_resp = Source.call(conn, Source.init([]))
      assert %SourceStruct{uri: ^uri, status: {:error, :einval}} = conn_resp.private.stow.source
      assert conn_resp.state != :set
      assert conn_resp.halted == true
    end

    test "raises when no http uri available", %{conn: conn} do
      assert_raise(ArgumentError, fn -> Source.call(conn, Source.init([])) end)
    end
  end
end
