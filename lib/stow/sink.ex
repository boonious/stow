defmodule Stow.Sink do
  @moduledoc """
  Behaviour for writing and deleting data.
  """

  @enforce_keys [:uri]
  defstruct [:uri, :status, :options]

  @type t :: %__MODULE__{
          uri: binary() | nil,
          status: nil | :ok | {:error, term()},
          options: %{String.t() => keyword()}
        }

  @type uri :: URI.t()
  @type data :: iodata()
  @type options :: keyword()

  @callback delete(uri(), options()) :: {:ok, uri()} | {:error, File.posix()}
  @callback put(uri(), data, options()) :: {:ok, uri()} | {:error, File.posix()}

  def new(uri, options \\ nil), do: %__MODULE__{uri: uri, options: options}
end
