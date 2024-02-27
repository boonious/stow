defmodule Stow.Plug.SinkTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Hammox
  import Stow.Plug.Utils, only: [update_private: 3]

  alias Plug.Conn
  alias Stow.FileIOMock, as: FileIO
  alias Stow.Plug.Sink
  alias Stow.Sink, as: SinkStruct

  defmodule FileSinkTestPlug do
    use Plug.Builder
    plug(Sink, uri: "file:/path/to/file", data: "test data")
  end

  setup :verify_on_exit!

  describe "file sink" do
    setup do
      FileIO |> stub(:exists?, fn _dir -> true end)
      %{conn: conn(:get, "/test"), path: "/path/to/file", data: "test data"}
    end

    test "via compiled plug opts", %{conn: conn, path: path, data: data} do
      dir = Path.dirname(path)
      uri = "file:#{path}"

      FileIO |> expect(:exists?, fn ^dir -> true end)
      FileIO |> expect(:write, fn ^path, ^data, [] -> :ok end)

      assert %Conn{} = conn = __MODULE__.FileSinkTestPlug.call(conn, [])
      assert %SinkStruct{uri: ^uri, status: :ok} = conn.private.stow.sink
    end

    test "via runtime plug opts", %{conn: conn} do
      {path, data} = {"/another/path/file", "others"}
      dir = Path.dirname(path)
      uri = "file:#{path}"

      FileIO |> expect(:exists?, fn ^dir -> true end)
      FileIO |> expect(:write, fn ^path, ^data, [] -> :ok end)

      assert %Conn{} = conn = Sink.call(conn, uri: uri, data: data)
      assert %SinkStruct{uri: ^uri, status: :ok} = conn.private.stow.sink
    end

    test "via connection private params", %{conn: conn, path: path, data: data} do
      conn = resp(conn, 200, data)
      conn = update_private(conn, :sink, SinkStruct.new("file:#{path}"))
      uri = "file:#{path}"

      FileIO |> expect(:write, fn ^path, ^data, [] -> :ok end)

      assert %Conn{} = conn = Sink.call(conn, [])
      assert %SinkStruct{uri: ^uri, status: :ok} = conn.private.stow.sink
    end

    test "error status on malformed file uri", %{conn: conn, data: data} do
      FileIO |> expect(:write, 0, fn _path, _data, [] -> :ok end)
      assert %Conn{} = conn = Sink.call(conn, uri: "no_scheme_uri", data: "")
      assert %SinkStruct{uri: nil, status: {:error, :einval}} = conn.private.stow.sink

      conn = resp(conn, 200, data)
      conn = update_private(conn, :sink, SinkStruct.new("no_scheme_uri"))
      assert %Conn{} = conn = Sink.call(conn, [])
      assert %SinkStruct{uri: nil, status: {:error, :einval}} = conn.private.stow.sink
    end

    test "error status when no file uri available", %{conn: conn, data: data} do
      FileIO |> expect(:write, 0, fn _path, _data, [] -> :ok end)

      conn = resp(conn, 200, data)
      assert %Conn{} = conn = Sink.call(conn, [])
      assert %SinkStruct{uri: nil, status: {:error, :einval}} = conn.private.stow.sink
    end

    test "error status without data option and respond body", %{conn: conn, path: path} do
      FileIO |> expect(:write, 0, fn _path, _data, [] -> :ok end)
      uri = "file:#{path}"

      assert %Conn{} = conn = Sink.call(conn, uri: uri)
      assert %SinkStruct{uri: ^uri, status: {:error, :einval}} = conn.private.stow.sink
    end

    test "error status when respond body invalid", %{conn: conn, path: path} do
      FileIO |> expect(:write, 0, fn _path, _data, [] -> :ok end)
      uri = "file:#{path}"

      conn = resp(conn, 500, "Internal Server Error")
      conn = update_private(conn, :sink, SinkStruct.new(uri))
      assert %Conn{} = conn = Sink.call(conn, [])
      assert %SinkStruct{uri: ^uri, status: {:error, :einval}} = conn.private.stow.sink
    end
  end
end
