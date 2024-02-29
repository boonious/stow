defmodule Stow.Sink.FileSink do
  defmodule MalformedURIError do
    defexception message: "invalid file uri"

    def exception(uri), do: %MalformedURIError{message: "invalid file uri (#{inspect(uri)})"}
  end

  @moduledoc """
  A sink for writing and deleting local file data.
  """

  @behaviour Stow.Sink

  import Stow.Pipeline, only: [base_dir: 1]

  @file_io Application.compile_env(:stow, :file_io, Elixir.File)
  @options [:base_dir, :modes, :file_io]

  @doc """
  Writing data to a local file location specified with a `URI.t()` identifier.

  ## Examples
  ```
    "file:/path/to/file.gz"
    |> URI.new!()
    |> Stow.Sink.FileSink.put("hello word", [:compressed])
  ```
  """
  @impl true
  def put(%URI{scheme: "file", host: nil, path: path} = uri, data, opts) when not is_nil(path) do
    with opts <- validate_opts(opts),
         path <- [base_dir(opts), path],
         :ok <- maybe_create_dir(path),
         :ok <- write_file(path, data, opts) do
      {:ok, uri}
    end
  end

  def put(uri, _data, _opts), do: raise(__MODULE__.MalformedURIError.exception(uri))

  defp validate_opts(opts), do: Keyword.validate!(opts, @options)

  defp maybe_create_dir(path) do
    dir = path |> Path.dirname()

    case dir |> @file_io.exists?() do
      true -> :ok
      false -> @file_io.mkdir_p(dir)
    end
  end

  defp write_file(path, data, opts) do
    file_modes = Keyword.get(opts, :modes, [])
    Keyword.get(opts, :file_io, @file_io).write(path, data, file_modes)
  end

  @doc """
  Deleting a local file.

  ## Examples
  ```
    "file:/path/to/file.gz"
    |> URI.new!()
    |> Stow.Sink.FileSink.delete(opts)
  ```
  """
  @impl true
  def delete(%URI{scheme: "file", host: nil, path: path} = uri, opts) when not is_nil(path) do
    case [validate_opts(opts) |> base_dir(), path] |> @file_io.rm() do
      :ok -> {:ok, uri}
      {:error, reason} -> {:error, reason}
    end
  end
end
