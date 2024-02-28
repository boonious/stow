defmodule Stow.Pipeline do
  @moduledoc false

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
    end
  end

  @spec conn() :: Plug.Conn.t()
  def conn(), do: %Plug.Conn{owner: self(), remote_ip: {127, 0, 0, 1}}
end
