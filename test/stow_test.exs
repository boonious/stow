defmodule StowTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Hammox

  alias Stow.Plug.Sink
  alias Stow.Plug.Source

  setup :verify_on_exit!

  setup do
    http_resp = {200, [{"content-type", "text/html; charset=utf-8"}], "hi"}

    stub(Stow.FileIOMock, :exists?, fn _dir -> true end)
    stub(Stow.FileIOMock, :write, fn _path, _data, _opts -> :ok end)
    stub(Stow.Http.ClientMock, :dispatch, fn _conn, _opts -> {:ok, http_resp} end)

    %{conn: conn(:get, "/")}
  end

  describe "status/2 ok" do
    test "for Stow.Plug.Sink", %{conn: conn} do
      Plug.run(conn, [{Sink, [uri: "file:/local/path/to/file", data: ""]}])
      |> Stow.status(Sink)
      |> then(fn plug_status -> assert plug_status == :ok end)
    end

    test "for Stow.Plug.Source", %{conn: conn} do
      Plug.run(conn, [{Source, [uri: "http://localhost/path/to/source?foo=bar"]}])
      |> Stow.status(Source)
      |> then(fn plug_status -> assert plug_status == :ok end)
    end
  end

  describe "status/2 error" do
    test "for Stow.Plug.Sink", %{conn: conn} do
      Plug.run(conn, [{Sink, [uri: "invalid/file/path", data: ""]}])
      |> Stow.status(Sink)
      |> then(fn plug_status -> {:error, _reason} = assert plug_status end)
    end

    test "for Stow.Plug.Source", %{conn: conn} do
      Plug.run(conn, [{Source, [uri: "non_valid_scheme://localhost/path/to/source?foo=bar"]}])
      |> Stow.status(Source)
      |> then(fn plug_status -> {:error, _reason} = assert plug_status end)
    end
  end
end
