defmodule Stow.FileIO do
  @moduledoc false

  @callback mkdir_p(Path.t()) :: :ok | {:error, File.posix()}
  @callback exists?(Path.t()) :: boolean()

  @callback rm(Path.t()) :: :ok | {:error, File.posix()}
  @callback write(Path.t(), iodata(), list()) :: :ok | {:error, File.posix()}
end
