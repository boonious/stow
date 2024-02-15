defmodule Stow.Sinks.FileSink do
  defmodule MalformedURIError do
    defexception message: "invalid file uri"

    def exception(uri), do: %MalformedURIError{message: "invalid file uri (#{inspect(uri)})"}
  end

  @moduledoc """
  A sink for writing and deleting local file data.
  """

  @behaviour Stow.Sink

  @file_io Application.compile_env(:stow, :file_io, Elixir.File)

  @doc """
  Writing data to a local file location specified with a `URI.t()` identifier.

  ## Examples
  ```
    "file:/path/to/file.gz"
    |> URI.new!()
    |> Stow.Sinks.FileSink.put("hello word", [:compressed])
  ```
  """
  @impl true
  def put(%URI{scheme: "file", host: nil, path: path} = uri, data, opts) when not is_nil(path) do
    with :ok <- maybe_create_dir(uri.path |> Path.dirname()),
         :ok <- write_file(uri.path, data, opts) do
      {:ok, uri}
    end
  end

  def put(uri, _data, _opts), do: raise(__MODULE__.MalformedURIError.exception(uri))

  defp maybe_create_dir(dir), do: if(@file_io.exists?(dir), do: :ok, else: @file_io.mkdir_p(dir))

  defp write_file(path, data, opts) do
    file_io = Keyword.get(opts, :file_io, @file_io)
    file_io.write(path, data, Keyword.get(opts, :mode, []))
  end

  @doc """
  Deleting a local file.

  ## Examples
  ```
    "file:/path/to/file.gz"
    |> URI.new!()
    |> Stow.Sinks.FileSink.delete()
  ```
  """
  @impl true
  def delete(%URI{scheme: "file", host: nil, path: path} = uri) when not is_nil(path) do
    case @file_io.rm(path) do
      :ok -> {:ok, uri}
      {:error, reason} -> {:error, reason}
    end
  end
end
