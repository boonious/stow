defmodule Stow.Sink do
  @moduledoc """
  Behaviour for writing and deleting data.
  """

  defstruct [:uri, :status, extras: []]

  @type t :: %__MODULE__{
          uri: binary() | nil,
          status: nil | :ok | {:error, term()},
          extras: keyword()
        }

  @type uri :: URI.t()
  @type data :: iodata()
  @type options :: keyword()

  @callback delete(uri(), options()) :: {:ok, uri()} | {:error, File.posix()}
  @callback put(uri(), data, options()) :: {:ok, uri()} | {:error, File.posix()}

  def new(uri, extras \\ []), do: %__MODULE__{uri: uri, extras: extras}
  def done(uri), do: %__MODULE__{uri: uri, status: :ok}
  def failed(error), do: %__MODULE__{status: error}
end
