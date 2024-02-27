defmodule Stow.Pipeline do
  @moduledoc false

  alias Stow.Sink
  alias Stow.Source

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

  def new(opts \\ []) do
    %__MODULE__{
      source: uri(Keyword.get(opts, :source_uri), Source),
      sink: uri(Keyword.get(opts, :sink_uri), Sink)
    }
  end

  defp uri(%Sink{} = sink, _type_module), do: sink
  defp uri(%Source{} = source, _type_module), do: source
  defp uri(uri, type_module) when is_binary(uri), do: type_module.new(uri)
  defp uri(nil, _), do: nil
end
