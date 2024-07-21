defmodule Stow.Adapter.File do
  @moduledoc false
  @behaviour Stow.Adapter

  import Stow.Config, only: [base_dir: 1, file_io: 0]
  alias Stow.Conn

  @impl true
  def dispatch(%Conn{method: :put, uri: %{scheme: "file"}} = conn) do
    with opts <- validate_opts(conn.opts),
         path <- path_with_base_dir(conn.uri.path, opts),
         :ok <- maybe_create_dir(path, opts) do
      Keyword.get(opts, :file_io).write(path, conn.body, Keyword.get(opts, :modes))
    end
  end

  def dispatch(%Conn{method: :delete, uri: %{scheme: "file"}} = conn) do
    with opts <- validate_opts(conn.opts),
         path <- path_with_base_dir(conn.uri.path, opts) do
      Keyword.get(opts, :file_io).rm(path)
    end
  end

  defp path_with_base_dir(path, opts), do: [Keyword.get(opts, :base_dir), path]

  defp maybe_create_dir(path, opts) do
    file_io = Keyword.get(opts, :file_io)
    dir = path |> Path.join() |> Path.dirname()

    case dir |> file_io.exists?() do
      true -> :ok
      false -> file_io.mkdir_p(dir)
    end
  end

  defp validate_opts(opts) do
    Keyword.validate!(opts,
      base_dir: base_dir(opts),
      modes: [],
      file_io: file_io()
    )
  end
end
