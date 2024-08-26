defmodule Stow.Source.HttpTest do
  use ExUnit.Case, async: true

  import Hammox

  alias Stow.Conn
  alias Stow.Adapter.HttpMock

  setup :verify_on_exit!

  setup do
    {status, headers, body} = {200, [], "hi"}

    %{
      resp: {:ok, {status, headers, body}},
      conn: Conn.new("https://localhost:123/path/to?foo=bar")
    }
  end

  describe "call/1" do
    test "http source", %{conn: conn, resp: resp} do
      %{scheme: scheme, host: host, path: path, port: port, query: query} = conn.uri

      HttpMock
      |> expect(:dispatch, fn conn ->
        assert %Stow.URI{host: ^host, path: ^path, port: ^port, query: ^query} = conn.uri
        assert conn.method == :get
        assert conn.uri.scheme == scheme

        resp
      end)

      assert ^resp = conn |> Stow.Source.Http.call()
    end
  end
end
