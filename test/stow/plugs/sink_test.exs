defmodule Stow.Plugs.SinkTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Hammox

  alias Stow.FileIO.Mock, as: FileIO
  alias Stow.Plugs.Sink

  defmodule FileSinkTestPlug do
    use Plug.Builder
    plug(Sink, uri: "file:/path/to/file", data: "test data")
  end

  setup :verify_on_exit!

  describe "file sink" do
    setup do
      FileIO |> stub(:exists?, fn _dir -> true end)
      %{path: "/path/to/file", data: "test data"}
    end

    test "via compiled plug opts", %{path: path, data: data} do
      conn = conn(:get, "/test")
      dir = Path.dirname(path)

      FileIO |> expect(:exists?, fn ^dir -> true end)
      FileIO |> expect(:write, fn ^path, ^data, [] -> :ok end)

      # need to assert/set conn private per file sink outcome later
      # create a file sink struct
      __MODULE__.FileSinkTestPlug.call(conn, [])
    end

    test "via runtime plug opts" do
      conn = conn(:get, "/test")
      {path, data} = {"/another/path/file", "others"}
      dir = Path.dirname(path)

      FileIO |> expect(:exists?, fn ^dir -> true end)
      FileIO |> expect(:write, fn ^path, ^data, [] -> :ok end)

      # need to assert/set conn private per file sink outcome later
      # create a file sink struct
      Sink.call(conn, uri: "file:#{path}", data: data)
    end

    test "via connection private params", %{path: path, data: data} do
      conn = conn(:get, "/test_conn")
      conn = resp(conn, 200, data)
      conn = put_private(conn, :stow, %{file_sink: %{uri: "file:#{path}"}})

      # need to assert/set conn private per file sink outcome later
      # create a file sink struct
      FileIO |> expect(:write, fn ^path, ^data, [] -> :ok end)
      Sink.call(conn, [])
    end

    # unhappy paths tests later
  end
end
