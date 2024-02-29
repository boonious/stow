defmodule Stow.Sink.FileSinkTest do
  use ExUnit.Case, async: true

  import Hammox

  alias Stow.FileIOMock, as: FileIO
  alias Stow.Sink.FileSink

  setup :verify_on_exit!

  setup_all do
    uri_s = "file:/path/to/local/file"
    uri = URI.new!(uri_s)
    base_dir = "."

    %{
      data: %{"binary" => "hi james", "io_list" => ["hi", 74, 97, 109, 101, 115]},
      opts: [base_dir: base_dir],
      path: [base_dir, uri.path],
      uri: uri,
      uri_s: uri_s
    }
  end

  describe "put/3" do
    setup do
      FileIO |> stub(:exists?, fn _file_dir -> true end)
      :ok
    end

    test "binary to file", %{data: data, opts: opts, path: path, uri: uri} do
      data = data["binary"]

      FileIO |> expect(:write, fn ^path, ^data, [] -> :ok end)
      assert {:ok, ^uri} = FileSink.put(uri, data, opts)
    end

    test "io list to file", %{data: data, opts: opts, path: path, uri: uri} do
      data = data["io_list"]

      FileIO |> expect(:write, fn ^path, ^data, [] -> :ok end)
      FileSink.put(uri, data, opts)
    end

    test "create non-existing file sub-directories", %{data: data, path: path} = context do
      data = data["binary"]
      dir = path |> Path.dirname()

      FileIO |> expect(:exists?, fn ^dir -> false end)
      FileIO |> expect(:mkdir_p, fn ^dir -> :ok end)
      FileIO |> expect(:write, fn ^path, ^data, [] -> :ok end)

      FileSink.put(context.uri, data, context.opts)
    end

    test "writes to configured dir without base_dir option", %{data: data} = context do
      data = data["binary"]
      path = [Application.get_env(:stow, :base_dir), context.uri.path]

      FileIO |> expect(:write, fn ^path, ^data, [] -> :ok end)
      FileSink.put(context.uri, data, [])
    end

    test "writes to an opted base_dir", %{data: data} = context do
      data = data["binary"]
      base_dir = "./this/is/an/alternative/base_dir"
      path = [base_dir, context.uri.path]

      FileIO |> expect(:write, fn ^path, ^data, [] -> :ok end)
      FileSink.put(context.uri, data, base_dir: base_dir)
    end

    test "with file modes option", %{data: data} = context do
      data = data["binary"]
      path = context.path

      modes_opt = [:compressed, :append]
      opts = Keyword.put_new(context.opts, :modes, modes_opt)

      FileIO |> expect(:write, fn ^path, ^data, ^modes_opt -> :ok end)
      FileSink.put(context.uri, data, opts)
    end

    test "returns error given invalid data", %{uri: uri} do
      invalid_data = %{"not" => "valid io data"}
      opts = [file_io: File, base_dir: "."]
      assert {:error, :badarg} = FileSink.put(uri, invalid_data, opts)
    end

    test "raises on invalid file uri", %{data: data, opts: opts} do
      data = data["binary"]
      invalid_uri = URI.new!("file:")

      assert_raise(FileSink.MalformedURIError, ~r/invalid file uri/, fn ->
        FileSink.put(invalid_uri, data, opts)
      end)

      invalid_uri = URI.new!("s3://bucket/path/to/file")

      assert_raise(FileSink.MalformedURIError, ~r/invalid file uri/, fn ->
        FileSink.put(invalid_uri, data, opts)
      end)
    end
  end

  describe "delete/2" do
    test "existing file", %{opts: opts, path: path, uri: uri} do
      FileIO |> expect(:rm, fn ^path -> :ok end)
      assert {:ok, ^uri} = FileSink.delete(uri, opts)
    end

    test "returns error tuple on deletion error", %{opts: opts, path: path, uri: uri} do
      # file does not exist
      FileIO |> expect(:rm, fn ^path -> {:error, :enoent} end)
      assert {:error, :enoent} = FileSink.delete(uri, opts)
    end
  end
end
