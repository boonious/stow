defmodule Stow.Source do
  @moduledoc """
  Behaviour for fetching data from various URI sources.
  """

  alias Stow.Http.Client, as: HttpClient

  defstruct [:uri, :status]

  @type t :: %__MODULE__{
          uri: binary() | nil,
          status: nil | :ok | {:error, term()}
        }

  @type conn :: Plug.Conn.t()
  @type options :: keyword()

  @callback get(conn(), options()) :: HttpClient.response()

  def new(uri), do: %__MODULE__{uri: uri}
  def done(uri), do: %__MODULE__{uri: uri, status: :ok}
  def failed(error, uri \\ nil), do: %__MODULE__{uri: uri, status: error}
end
