defmodule StowTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Hammox

  setup :verify_on_exit!

  setup do
    http_resp = {200, [{"content-type", "text/html; charset=utf-8"}], "hi"}

    stub(Stow.FileIOMock, :exists?, fn _dir -> true end)
    stub(Stow.FileIOMock, :write, fn _path, _data, _opts -> :ok end)
    stub(Stow.Adapter.HttpMock, :dispatch, fn _conn -> {:ok, http_resp} end)

    :ok
  end

  test "source/1" do
    assert {:ok, _resp} = Stow.source("http://localhost:123/path/to?foo=bar")
    assert {:ok, _resp} = Stow.source("https://localhost:123/path/to?foo=bar")
  end

  test "sink/2" do
    assert :ok = Stow.sink("file:///path/to/file", "data to save")
  end
end
