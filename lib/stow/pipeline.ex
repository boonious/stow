defmodule Stow.Pipeline do
  @moduledoc false

  @default_base_dir "./stow_data"
  @base_dir Application.compile_env(:stow, :base_dir)

  defstruct [:source, :sink]

  @type t :: %__MODULE__{
          source: Stow.Source.t(),
          sink: Stow.Sink.t()
        }

  defmacro __using__(opts) do
    quote do
      use Plug.Builder, unquote(opts)
      import Stow.Pipeline
      alias Stow.Pipeline

      plug(:first)

      # Plug always run the first plug
      # before halting a pipeline.
      # This plug enables halting through a halted conn via `super`
      def first(conn, _opts), do: conn
    end
  end

  @spec conn() :: Plug.Conn.t()
  def conn(), do: %Plug.Conn{owner: self(), remote_ip: {127, 0, 0, 1}}

  @doc false
  def base_dir(opts \\ []) do
    Keyword.get(opts, :base_dir, @base_dir) ||
      System.get_env("LB_STOW_BASE_DIR") ||
      default_base_dir()
  end

  def default_base_dir, do: @default_base_dir
end
