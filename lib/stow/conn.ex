defmodule Stow.Conn do
  @moduledoc false

  import Stow.Adapter, only: [impl: 1]

  @type header :: {charlist(), charlist()} | {binary(), binary()}
  @type header_key :: iodata()
  @type header_value :: iodata()

  @type t :: %__MODULE__{
          adapter: module() | function(),
          body: nil | iodata(),
          halted: boolean(),
          headers: [header()],
          method: atom(),
          opts: keyword(),
          status: nil | non_neg_integer(),
          uri: Stow.URI.t()
        }

  defstruct [
    :adapter,
    :body,
    :status,
    :uri,
    halted: false,
    headers: [],
    method: :get,
    opts: []
  ]

  def new(uri, method \\ :get)

  def new(%URI{} = uri, method) do
    %__MODULE__{uri: Stow.URI.new(uri), method: method, adapter: impl(uri.scheme)}
  end

  def new("http" <> _ = uri, method) do
    %__MODULE__{uri: Stow.URI.new(uri), method: method, adapter: impl("http")}
  end

  def new("file:/" <> _ = uri, method) do
    %__MODULE__{uri: Stow.URI.new(uri), method: method, adapter: impl("file")}
  end
end
