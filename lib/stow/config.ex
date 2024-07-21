defmodule Stow.Config do
  @moduledoc false

  @base_dir Application.compile_env(:stow, :base_dir)
  @file_io Application.compile_env(:stow, :file_io, Elixir.File)

  @default_base_dir "./stow_data"
  @default_file_adapter Stow.Adapter.File
  @default_http_adapter Stow.Adapter.Http.Httpc

  def base_dir(opts \\ []) do
    Keyword.get(opts, :base_dir, @base_dir) ||
      System.get_env("LB_STOW_BASE_DIR") ||
      default_base_dir()
  end

  def default_adapter("file"), do: @default_file_adapter
  def default_adapter("http"), do: @default_http_adapter
  def default_base_dir, do: @default_base_dir
  def file_io, do: @file_io

  def adapter(scheme \\ "http") do
    Application.get_env(:stow, :adapter)[scheme] ||
      System.get_env("LB_STOW_ADAPTER")[scheme] ||
      default_adapter(scheme)
  end
end
