defmodule Stow.Plug.SinkTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Hammox
  import Stow.Pipeline, only: [base_dir: 0]
  import Stow.Plug.Utils, only: [update_private: 3]

  alias Plug.Conn
  alias Stow.FileIOMock, as: FileIO
  alias Stow.Plug.Sink
  alias Stow.Sink, as: SinkStruct

  defmodule FileSinkTestPlug do
    use Plug.Builder

    plug(Sink,
      uri: "file:/path/to/file",
      data: "test data",
      options: %{"file" => [modes: [:compressed]]}
    )
  end

  setup :verify_on_exit!

  setup_all do
    uri_s = "file:/path/to/file"
    uri = URI.new!(uri_s)

    %{
      conn: conn(:get, "/test"),
      data: "test data",
      path: [base_dir(), uri.path],
      uri: uri,
      uri_s: uri_s
    }
  end

  describe "sink" do
    setup do
      FileIO |> stub(:exists?, fn _dir -> true end)
      :ok
    end

    test "via compiled plug opts", %{data: data, path: path, uri_s: uri_s} = context do
      dir = path |> Path.dirname()

      FileIO |> expect(:exists?, fn ^dir -> true end)
      FileIO |> expect(:write, fn ^path, ^data, [:compressed] -> :ok end)

      assert %Conn{} = conn = __MODULE__.FileSinkTestPlug.call(context.conn, [])
      assert %SinkStruct{uri: ^uri_s, status: :ok} = conn.private.stow.sink
    end

    test "via runtime plug opts", %{conn: conn} do
      {path, data} = {[base_dir(), "/another/path/file"], "others"}
      dir = Path.dirname(path)
      uri = "file:/another/path/file"

      FileIO |> expect(:exists?, fn ^dir -> true end)
      FileIO |> expect(:write, fn ^path, ^data, [] -> :ok end)

      assert %Conn{} = conn = Sink.call(conn, uri: uri, data: data)
      assert %SinkStruct{uri: ^uri, status: :ok} = conn.private.stow.sink
    end

    test "via connection private params", %{data: data, path: path, uri_s: uri_s} = context do
      options = %{"file" => [modes: [:compressed]]}
      conn = resp(context.conn, 200, data)
      conn = update_private(conn, :sink, SinkStruct.new(uri_s, options))

      FileIO |> expect(:write, fn ^path, ^data, [:compressed] -> :ok end)

      assert %Conn{} = conn = Sink.call(conn, [])
      assert %SinkStruct{uri: ^uri_s, status: :ok, options: ^options} = conn.private.stow.sink
    end

    test "with options", %{data: data, path: [_base_dir, path]} = context do
      base_dir = "./another/dir"
      path = [base_dir, path]
      dir = path |> Path.dirname()

      opts = [
        uri: context.uri_s,
        data: data,
        options: %{"file" => [base_dir: base_dir, modes: [:compressed]]}
      ]

      FileIO |> expect(:exists?, fn ^dir -> true end)
      FileIO |> expect(:write, fn ^path, ^data, [:compressed] -> :ok end)

      Sink.call(context.conn, opts)
    end
  end

  describe "sink errors" do
    test "on malformed file uri", %{conn: conn, data: data} do
      FileIO |> expect(:write, 0, fn _path, _data, [] -> :ok end)
      assert %Conn{} = conn = Sink.call(conn, uri: "no_scheme_uri", data: "")
      assert %SinkStruct{uri: "no_scheme_uri", status: {:error, :einval}} = conn.private.stow.sink

      conn = resp(conn, 200, data)
      conn = update_private(conn, :sink, SinkStruct.new("no_scheme_uri"))

      assert %Conn{} = conn = Sink.call(conn, [])
      assert %SinkStruct{uri: "no_scheme_uri", status: {:error, :einval}} = conn.private.stow.sink
    end

    test "when no file uri available", %{conn: conn, data: data} do
      FileIO |> expect(:write, 0, fn _path, _data, [] -> :ok end)

      conn = resp(conn, 200, data)
      assert_raise(ArgumentError, fn -> Sink.call(conn, []) end)
    end

    test "without data option and respond body", %{conn: conn, uri_s: uri_s} do
      FileIO |> expect(:write, 0, fn _path, _data, [] -> :ok end)

      assert %Conn{} = conn = Sink.call(conn, uri: uri_s)
      assert %SinkStruct{uri: ^uri_s, status: {:error, :einval}} = conn.private.stow.sink
    end

    test "when respond body invalid", %{conn: conn, uri_s: uri_s} do
      FileIO |> expect(:write, 0, fn _path, _data, [] -> :ok end)

      conn = resp(conn, 500, "Internal Server Error")
      conn = update_private(conn, :sink, SinkStruct.new(uri_s))
      assert %Conn{} = conn = Sink.call(conn, [])
      assert %SinkStruct{uri: ^uri_s, status: {:error, :einval}} = conn.private.stow.sink
    end
  end
end
