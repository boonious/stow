defmodule Stow.Source do
  @moduledoc """
  Behaviour for fetching data from various URI sources.
  """

  @enforce_keys [:uri]
  defstruct [:uri, :status, :options]

  @type t :: %__MODULE__{
          uri: binary() | nil,
          status: nil | :ok | {:error, term()},
          options: %{String.t() => %{atom() => keyword()}}
        }

  @type conn :: Plug.Conn.t()

  @callback get(conn(), map()) :: term()

  def new(uri, options \\ nil), do: %__MODULE__{uri: uri, options: options}
end
