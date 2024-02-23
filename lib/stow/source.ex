defmodule Stow.Source do
  @moduledoc """
  Behaviour for fetching data from various URI sources.
  """

  alias Stow.Http.Client, as: HttpClient

  defstruct [:uri, :status, req_headers: [], resp_headers: []]

  @type t :: %__MODULE__{
          uri: binary() | nil,
          req_headers: [tuple()],
          resp_headers: [tuple()],
          status: nil | :ok | {:error, term()}
        }

  @type conn :: Plug.Conn.t()
  @type options :: keyword()

  @callback get(conn(), options()) :: HttpClient.response()

  def new(uri, headers \\ []) do
    %__MODULE__{
      uri: uri,
      req_headers: Keyword.get(headers, :req_headers, []),
      resp_headers: Keyword.get(headers, :resp_headers, [])
    }
  end

  def done(uri), do: %__MODULE__{uri: uri, status: :ok}
  def failed(error, uri \\ nil), do: %__MODULE__{uri: uri, status: error}
end
