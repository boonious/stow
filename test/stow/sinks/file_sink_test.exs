defmodule Stow.Sinks.FileSinkTest do
  use ExUnit.Case, async: true

  import Hammox

  alias Stow.FileIO
  alias Stow.Sinks.FileSink

  setup :verify_on_exit!

  setup do
    FileIO.Mock |> stub(:exists?, fn _file_dir -> true end)

    %{
      data: %{"binary" => "hi james", "io_list" => ["hi", 74, 97, 109, 101, 115]},
      file_uri: "file:/path/to/local/file" |> URI.new!()
    }
  end

  describe "put/3" do
    test "binary to file", %{data: data, file_uri: uri} do
      data = data["binary"]
      path = uri.path
      opts = []

      FileIO.Mock |> expect(:write, fn ^path, ^data, ^opts -> :ok end)
      assert {:ok, ^uri} = FileSink.put(uri, data, opts)
    end

    test "io list to file", %{data: data, file_uri: uri} do
      data = data["io_list"]
      path = uri.path
      opts = []

      FileIO.Mock |> expect(:write, fn ^path, ^data, ^opts -> :ok end)
      FileSink.put(uri, data, opts)
    end

    test "create non-existing file sub-directories", %{data: data, file_uri: uri} do
      data = data["binary"]
      path = uri.path
      dir = uri.path |> Path.dirname()
      opts = []

      FileIO.Mock |> expect(:exists?, fn ^dir -> false end)
      FileIO.Mock |> expect(:mkdir_p, fn ^dir -> :ok end)
      FileIO.Mock |> expect(:write, fn ^path, ^data, ^opts -> :ok end)

      FileSink.put(uri, data, opts)
    end

    test "returns error given invalid data", %{file_uri: uri} do
      invalid_data = %{"not" => "valid io data"}
      opts = [file_io: File]
      assert {:error, :badarg} = FileSink.put(uri, invalid_data, opts)
    end

    test "raises on invalid file uri", %{data: data} do
      data = data["binary"]
      opts = []

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

  describe "delete/1" do
    test "existing file", %{file_uri: uri} do
      path = uri.path
      FileIO.Mock |> expect(:rm, fn ^path -> :ok end)
      assert {:ok, ^uri} = FileSink.delete(uri)
    end

    test "returns error tuple on deletion error", %{file_uri: uri} do
      path = uri.path

      # file does not exist
      FileIO.Mock |> expect(:rm, fn ^path -> {:error, :enoent} end)
      assert {:error, :enoent} = FileSink.delete(uri)
    end
  end
end
