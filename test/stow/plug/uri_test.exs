defmodule Stow.Plug.UriTest do
  use ExUnit.Case, async: true
  use Plug.Test

  alias Plug.Conn
  alias Stow.Plug.Uri
  alias Stow.{Sink, Source}

  defmodule SinkUriPlug do
    use Plug.Builder
    plug(Uri, uri: "file:/path/to/file", plug_type: :sink)
  end

  defmodule SourceUriPlug do
    use Plug.Builder
    plug(Uri, uri: "http://host/path/to/file", plug_type: :source)
  end

  setup_all do
    %{
      conn: conn(:get, "/test"),
      sink_uri: "file:/path/to/file",
      src_uri: "http://host/path/to/file"
    }
  end

  describe "plug" do
    test "via compile opts", %{conn: conn} do
      assert %Conn{} = __MODULE__.SinkUriPlug.call(conn, Uri.init([]))
      assert %Conn{} = __MODULE__.SourceUriPlug.call(conn, Uri.init([]))
    end

    test "via runtime opts", %{conn: conn} = context do
      uri = context.sink_uri
      opts = Uri.init(uri: uri, plug_type: :sink)
      assert %Conn{} = Uri.call(conn, opts)

      uri = context.src_uri
      opts = Uri.init(uri: uri, plug_type: :source)
      assert %Conn{} = Uri.call(conn, opts)
    end

    test "binary uri option", %{conn: conn} = context do
      uri = context.sink_uri
      opts = Uri.init(uri: uri, plug_type: :sink)
      conn = Uri.call(conn, opts)
      assert %Sink{uri: ^uri, status: nil} = conn.private.stow.sink

      uri = context.src_uri
      opts = Uri.init(uri: uri, plug_type: :source)
      conn = Uri.call(conn, opts)
      assert %Source{uri: ^uri, status: nil} = conn.private.stow.source
    end

    test "uri struct option ", %{conn: conn} = context do
      uri = context.sink_uri |> URI.new!()
      opts = Uri.init(uri: uri, plug_type: :sink)
      conn = Uri.call(conn, opts)
      assert %Sink{uri: ^uri, status: nil} = conn.private.stow.sink

      uri = context.src_uri |> URI.new!()
      opts = Uri.init(uri: uri, plug_type: :source)
      conn = Uri.call(conn, opts)
      assert %Source{uri: ^uri, status: nil} = conn.private.stow.source
    end

    test "raises on missing some and all opts", %{conn: conn} = context do
      assert_raise(KeyError, fn -> Uri.call(conn, Uri.init([])) end)
      assert_raise(KeyError, fn -> Uri.call(conn, Uri.init(plug_type: :sink)) end)
      assert_raise(KeyError, fn -> Uri.call(conn, Uri.init(uri: context.sink_uri)) end)
    end
  end
end
