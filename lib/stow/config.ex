defmodule Stow.Config do
  @moduledoc false
  alias Stow.Http.Client

  @default_base_dir "./stow_data"
  @base_dir Application.compile_env(:stow, :base_dir)
  @file_io Application.compile_env(:stow, :file_io, Elixir.File)

  def base_dir(opts \\ []) do
    Keyword.get(opts, :base_dir, @base_dir) ||
      System.get_env("LB_STOW_BASE_DIR") ||
      default_base_dir()
  end

  def default_base_dir, do: @default_base_dir

  def file_io, do: @file_io

  def http_client(client \\ "httpc") do
    Application.get_env(:stow, :http_client, runtime_client(client))
  end

  defp runtime_client(client), do: client |> Macro.camelize() |> then(&Module.concat(Client, &1))

  def default_file_sink_opts do
    [
      base_dir: base_dir(),
      modes: [],
      file_io: file_io()
    ]
  end
end
