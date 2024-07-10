defmodule Stow.Conn do
  @moduledoc false

  defguard binary_header?(h) when is_binary(elem(h, 0)) and is_binary(elem(h, 1))

  @type header :: {charlist(), charlist()} | {binary(), binary()}
  @type header_key :: iodata()
  @type header_value :: iodata()

  @type t :: %__MODULE__{
          adapter: module() | function(),
          body: nil | iodata(),
          halted: boolean(),
          headers: [header()],
          method: atom(),
          opts: nil | keyword(),
          status: nil | non_neg_integer(),
          uri: Stow.URI.t()
        }

  defstruct [
    :adapter,
    :body,
    :opts,
    :status,
    :uri,
    halted: false,
    headers: [],
    method: :get
  ]

  def new(uri, adapter \\ Stow.Adapter.impl())
  def new(%URI{} = uri, adapter), do: %__MODULE__{uri: Stow.URI.new(uri), adapter: adapter}
  def new("http" <> _ = uri, adapter), do: %__MODULE__{uri: Stow.URI.new(uri), adapter: adapter}
end
