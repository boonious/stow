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

  setup_all do
    {status, headers, body} = {200, [{"content-type", "text/html; charset=utf-8"}], "hi"}
    resp = {:ok, {status, headers, body}}

    %{
      conn: conn(),
      resp: resp,
      sink_uri: "file:/path/to/file",
      src_uri: "http://online.com/api/source"
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
        source = URI.new!(context.src_uri)
        assert conn.host == source.host
        assert conn.port == source.port
        assert conn.scheme == :http
        assert conn.request_path == source.path

        context.resp
      end)

      SourceSink.call(context.conn, source: context.src_uri, sink: context.sink_uri)
    end

    test "writes source to file", context do
      {:ok, {_status, _headers, body}} = context.resp
      uri = URI.new!(context.sink_uri)
      path = [Application.get_env(:stow, :base_dir), uri.path]
      dir = path |> Path.dirname()

      FileIO |> expect(:exists?, fn ^dir -> true end)
      FileIO |> expect(:write, fn ^path, ^body, [] -> :ok end)
      SourceSink.call(context.conn, source: context.src_uri, sink: context.sink_uri)
    end

    test "http response", %{conn: conn, sink_uri: sink_uri, src_uri: src_uri} = context do
      {:ok, {status, headers, body}} = context.resp
      assert %Conn{} = conn = SourceSink.call(conn, source: src_uri, sink: sink_uri)

      source = URI.new!(src_uri)
      assert conn.host == source.host
      assert conn.port == source.port
      assert conn.request_path == source.path
      assert conn.state == :set

      assert %{resp_body: ^body, status: ^status, scheme: :http} = conn
      for h <- headers, do: assert(h in conn.resp_headers)
    end

    test "sets private fields", %{sink_uri: sink_uri, src_uri: src_uri} = context do
      HttpClient
      |> expect(:dispatch, fn %{private: private}, [] ->
        assert %Pipeline{source: source, sink: sink} = private.stow
        assert source == Source.new(src_uri)
        assert sink == Sink.new(sink_uri)

        context.resp
      end)

      assert %Conn{} = conn = SourceSink.call(context.conn, source: src_uri, sink: sink_uri)

      assert %Pipeline{
               source: %Source{
                 status: :ok,
                 uri: ^src_uri,
                 extras: %{headers: %{req: [], resp: []}}
               },
               sink: %Sink{uri: ^sink_uri, status: :ok}
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
      assert %Conn{} = conn = SourceSink.call(conn, source: context.src_uri)
      assert %{halted: true, status: nil, state: :unset} = conn
    end

    test "when only sink is given", %{conn: conn} = context do
      assert %Conn{} = conn = SourceSink.call(conn, sink: context.sink_uri)
      assert %{halted: true, status: nil, state: :unset} = conn
    end

    test "with correct private fields", context do
      source_field = Source.new(context.src_uri)
      sink_field = Sink.new(context.sink_uri)

      conn = SourceSink.call(context.conn, [])
      assert %{} = conn.private

      conn = SourceSink.call(context.conn, source: context.src_uri)
      assert %Pipeline{source: ^source_field, sink: nil} = conn.private.stow

      conn = SourceSink.call(context.conn, sink: context.sink_uri)
      assert %Pipeline{source: nil, sink: ^sink_field} = conn.private.stow
    end
  end
end
