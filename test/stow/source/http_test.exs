defmodule Stow.Source.HttpTest do
  use ExUnit.Case, async: true

  import Hammox

  alias Stow.Conn
  alias Stow.AdapterMock

  setup :verify_on_exit!

  setup do
    {status, headers, body} = {200, [], "hi"}
    conn = Conn.new("https://localhost:123/path/to?foo=bar")

    %{
      resp: {:ok, {status, headers, body}},
      stow: %Stow{conn: conn, type: :source}
    }
  end

  describe "call/1" do
    test "http source", %{stow: stow, resp: resp} do
      %{scheme: scheme, host: host, path: path, port: port, query: query} = stow.conn.uri

      AdapterMock
      |> expect(:dispatch, fn conn ->
        assert %Stow.URI{host: ^host, path: ^path, port: ^port, query: ^query} = conn.uri
        assert conn.method == :get
        assert conn.uri.scheme == scheme

        resp
      end)

      assert ^resp = stow |> Stow.Source.Http.call()
    end
  end
end
