defmodule Stow.Sink do
  @moduledoc """
  Behaviour for writing and deleting data.
  """

  @type uri :: URI.t()
  @type data :: iodata()
  @type options :: keyword()

  @callback delete(uri()) :: {:ok, uri()} | {:error, File.posix()}
  @callback put(uri(), data, options()) :: {:ok, uri()} | {:error, File.posix()}
end
