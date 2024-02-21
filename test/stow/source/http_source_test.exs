defmodule Stow.Source.HttpSourceTest do
  use ExUnit.Case, async: true
  use Plug.Test

  import Hammox

  alias Plug.Conn
  alias Stow.Http.ClientMock, as: HttpClient
  alias Stow.Source.HttpSource

  setup :verify_on_exit!

  setup do
    {status, headers, body} = {200, [], "hi"}
    uri = URI.new!("http://localhost:123/path/to?foo=bar")

    %{
      conn: conn(:get, uri |> to_string()),
      resp: {:ok, {status, headers, body}},
      uri: uri
    }
  end

  describe "get/2" do
    test "http source", %{conn: conn, resp: resp, uri: uri} do
      %{host: host, path: path, port: port, query: query} = uri

      HttpClient
      |> expect(:dispatch, fn %Conn{
                                scheme: :http,
                                method: "GET",
                                host: ^host,
                                port: ^port,
                                request_path: ^path,
                                query_string: ^query
                              },
                              [] ->
        resp
      end)

      assert ^resp = HttpSource.get(conn, [])
    end
  end
end
