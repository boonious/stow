defmodule Stow.Sink do
  @moduledoc """
  Behaviour for writing and deleting data.
  """

  defstruct [:uri, :status]

  @type t :: %__MODULE__{
          uri: binary() | uri(),
          status: nil | :ok | {:error, term()}
        }

  @type uri :: URI.t()
  @type data :: iodata()
  @type options :: keyword()

  @callback delete(uri()) :: {:ok, uri()} | {:error, File.posix()}
  @callback put(uri(), data, options()) :: {:ok, uri()} | {:error, File.posix()}

  def new(uri), do: %__MODULE__{uri: uri}
  def done(uri), do: %__MODULE__{uri: uri, status: :ok}
  def failed(error), do: %__MODULE__{status: error}
end
