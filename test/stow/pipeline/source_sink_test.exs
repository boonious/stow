defmodule Stow.Pipeline.SourceSinkTest do
  use ExUnit.Case, async: true

  import Hammox
  import Stow.Pipeline, only: [conn: 0]

  alias Plug.Conn
  alias Stow.FileIOMock, as: FileIO
  alias Stow.Http.ClientMock, as: HttpClient
  alias Stow.{Pipeline, Source, Sink}
  alias Stow.Pipeline.SourceSink

  setup :verify_on_exit!

  setup do
    {status, headers, body} = {200, [{"content-type", "text/html; charset=utf-8"}], "hi"}
    resp = {:ok, {status, headers, body}}

    %{
      conn: conn(),
      resp: resp,
      path: "/path/to/file",
      source: "http://online.com/api/source"
    }
  end

  describe "call/2" do
    setup context do
      FileIO |> stub(:exists?, fn _dir -> true end)
      FileIO |> stub(:write, fn _path, _body, _opts -> :ok end)
      HttpClient |> stub(:dispatch, fn _conn, _opts -> context.resp end)

      :ok
    end

    test "dispatches get request to http source", context do
      HttpClient
      |> expect(:dispatch, fn %{state: :unset, status: nil} = conn, [] ->
        source = URI.new!(context.source)
        assert conn.host == source.host
        assert conn.port == source.port
        assert conn.scheme == :http
        assert conn.request_path == source.path

        context.resp
      end)

      SourceSink.call(context.conn, source: context.source, sink: "file:#{context.path}")
    end

    test "writes source to file", %{path: path} = context do
      {:ok, {_status, _headers, body}} = context.resp
      dir = Path.dirname(path)

      FileIO |> expect(:exists?, fn ^dir -> true end)
      FileIO |> expect(:write, fn ^path, ^body, [] -> :ok end)
      SourceSink.call(context.conn, source: context.source, sink: "file:#{path}")
    end

    test "http response", %{conn: conn, path: path, source: source} = context do
      {:ok, {status, headers, body}} = context.resp
      assert %Conn{} = conn = SourceSink.call(conn, source: source, sink: "file:#{path}")

      source = URI.new!(source)
      assert conn.host == source.host
      assert conn.port == source.port
      assert conn.request_path == source.path
      assert conn.state == :set

      assert %{resp_body: ^body, status: ^status, scheme: :http} = conn
      for h <- headers, do: assert(h in conn.resp_headers)
    end

    test "sets private fields", %{conn: conn, path: path, source: source} = context do
      HttpClient
      |> expect(:dispatch, fn %{private: private}, [] ->
        assert %Pipeline{source: source, sink: sink} = private.stow
        assert source == Source.new(context.source)
        assert sink == Sink.new("file:#{path}")

        context.resp
      end)

      path = "file:#{path}"
      assert %Conn{} = conn = SourceSink.call(conn, source: source, sink: path)

      assert %Pipeline{
               source: %Source{status: :ok, uri: ^source, req_headers: [], resp_headers: []},
               sink: %Sink{uri: ^path, status: :ok}
             } = conn.private.stow
    end
  end

  describe "call/2 halts pipeline" do
    setup context do
      FileIO |> expect(:exists?, 0, fn _dir -> true end)
      FileIO |> expect(:write, 0, fn _path, _body, _opts -> :ok end)
      HttpClient |> expect(:dispatch, 0, fn _conn, _opts -> context.resp end)
      :ok
    end

    test "without both source and sink options", %{conn: conn} do
      assert %Conn{} = conn = SourceSink.call(conn, [])
      assert %{halted: true, status: nil, state: :unset} = conn
    end

    test "when only source is given", %{conn: conn} = context do
      assert %Conn{} = conn = SourceSink.call(conn, source: context.source)
      assert %{halted: true, status: nil, state: :unset} = conn
    end

    test "when only sink is given", %{conn: conn} = context do
      assert %Conn{} = conn = SourceSink.call(conn, sink: "file:#{context.path}")
      assert %{halted: true, status: nil, state: :unset} = conn
    end

    test "with correct private fields", context do
      source_field = Source.new(context.source)
      sink_field = Sink.new("file:#{context.path}")

      conn = SourceSink.call(context.conn, [])
      assert %{} = conn.private

      conn = SourceSink.call(context.conn, source: context.source)
      assert %Pipeline{source: ^source_field, sink: nil} = conn.private.stow

      conn = SourceSink.call(context.conn, sink: "file:#{context.path}")
      assert %Pipeline{source: nil, sink: ^sink_field} = conn.private.stow
    end
  end
end
