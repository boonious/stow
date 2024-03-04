defmodule Stow.Source do
  @moduledoc """
  Behaviour for fetching data from various URI sources.
  """

  alias Stow.Http.Client, as: HttpClient
  alias Stow.Http.Headers
  alias Stow.Options

  defstruct [:uri, :status, options: %Options{}]

  @type t :: %__MODULE__{
          uri: binary() | nil,
          options: Options.t(),
          status: nil | :ok | {:error, term()}
        }

  @type conn :: Plug.Conn.t()
  @type options :: keyword()

  @callback get(conn(), options()) :: HttpClient.response()

  def new(uri, headers \\ []) do
    %__MODULE__{
      uri: uri,
      options: %Options{
        headers: %Headers{
          req: Keyword.get(headers, :req_headers, []),
          resp: Keyword.get(headers, :resp_headers, [])
        }
      }
    }
  end

  def done(uri), do: %__MODULE__{uri: uri, status: :ok}
  def failed(error, uri \\ nil), do: %__MODULE__{uri: uri, status: error}
end
