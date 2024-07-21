defmodule Stow.Sink.FileTest do
  use ExUnit.Case, async: true

  import Hammox

  alias Stow.Conn
  alias Stow.FileIOMock
  alias Stow.Sink.File, as: FileSink

  setup :verify_on_exit!

  setup_all do
    base_dir = "."

    conn = %{
      Conn.new("file:///path/to/local/file")
      | method: :put,
        body: "hi james",
        opts: [base_dir: base_dir]
    }

    %{
      base_dir: base_dir,
      stow: %Stow{conn: conn, type: :sink}
    }
  end

  describe "call/1 method put" do
    setup do
      FileIOMock |> stub(:exists?, fn _file_dir -> true end)
      :ok
    end

    test "binary to file", %{base_dir: dir, stow: stow} do
      data = stow.conn.body
      %{path: path} = stow.conn.uri

      FileIOMock |> expect(:write, fn [^dir, ^path], ^data, [] -> :ok end)
      assert :ok == FileSink.call(stow)
    end

    test "io list to file", %{stow: stow} do
      data = ["hi", 74, 97, 109, 101, 115]
      stow = put_in(stow, [Access.key!(:conn), Access.key!(:body)], data)

      FileIOMock |> expect(:write, fn _path, ^data, [] -> :ok end)
      assert :ok == FileSink.call(stow)
    end

    test "create non-existing file sub-directories", %{base_dir: base_dir, stow: stow} do
      data = stow.conn.body
      path = stow.conn.uri.path
      dir = [base_dir, path] |> Path.dirname()

      FileIOMock |> expect(:exists?, fn ^dir -> false end)
      FileIOMock |> expect(:mkdir_p, fn ^dir -> :ok end)
      FileIOMock |> expect(:write, fn [^base_dir, ^path], ^data, [] -> :ok end)

      assert :ok == FileSink.call(stow)
    end

    test "writes to configured dir without base_dir option", %{stow: stow} do
      data = stow.conn.body
      path = [Application.get_env(:stow, :base_dir), stow.conn.uri.path]

      FileIOMock |> expect(:write, fn ^path, ^data, [] -> :ok end)
      assert :ok == FileSink.call(stow)
    end

    test "writes to an opted base_dir", %{stow: stow} do
      data = stow.conn.body
      base_dir = "./this/is/an/alternative/base_dir"
      path = [base_dir, stow.conn.uri.path]

      stow = put_in(stow, [Access.key!(:conn), Access.key!(:opts)], base_dir: base_dir)

      FileIOMock |> expect(:write, fn ^path, ^data, [] -> :ok end)
      assert :ok == FileSink.call(stow)
    end

    test "with file modes option", %{base_dir: dir, stow: stow} do
      data = stow.conn.body
      path = [dir, stow.conn.uri.path]
      modes_opt = [:compressed, :append]
      opts = Keyword.put_new(stow.conn.opts, :modes, modes_opt)

      stow = put_in(stow, [Access.key!(:conn), Access.key!(:opts)], opts)

      FileIOMock |> expect(:write, fn ^path, ^data, ^modes_opt -> :ok end)
      assert :ok == FileSink.call(stow)
    end

    test "returns error given invalid data", %{stow: stow} do
      invalid_data = %{"not" => "valid io data"}
      opts = [file_io: File, base_dir: "."]

      conn = %{stow.conn | opts: opts, body: invalid_data}
      stow = %{stow | conn: conn}

      assert {:error, :badarg} = FileSink.call(stow)
    end

    test "raises on invalid file uri", %{stow: stow} do
      invalid_uri = URI.new!("file:")
      stow = put_in(stow, [Access.key!(:conn), Access.key!(:uri)], invalid_uri)

      assert_raise(Stow.URI.MalformedURIError, ~r/invalid file uri/, fn -> FileSink.call(stow) end)

      invalid_uri = URI.new!("s3://bucket/path/to/file")
      stow = put_in(stow, [Access.key!(:conn), Access.key!(:uri)], invalid_uri)

      assert_raise(Stow.URI.MalformedURIError, ~r/invalid file uri/, fn -> FileSink.call(stow) end)
    end
  end

  describe "call/1 method delete" do
    test "existing file", %{base_dir: dir, stow: stow} do
      stow = put_in(stow, [Access.key!(:conn), Access.key!(:method)], :delete)
      path = [dir, stow.conn.uri.path]

      FileIOMock |> expect(:rm, fn ^path -> :ok end)
      assert :ok == FileSink.call(stow)
    end

    test "returns error tuple on deletion error", %{base_dir: dir, stow: stow} do
      stow = put_in(stow, [Access.key!(:conn), Access.key!(:method)], :delete)
      path = [dir, stow.conn.uri.path]

      # file does not exist
      FileIOMock |> expect(:rm, fn ^path -> {:error, :enoent} end)
      assert {:error, :enoent} = FileSink.call(stow)
    end
  end
end
