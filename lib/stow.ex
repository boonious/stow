defmodule Stow do
  @moduledoc false

  alias Stow.Plug.Sink

  defstruct [:conn, :type]

  @type t :: %__MODULE__{
          conn: Stow.Conn.t(),
          type: :source | :sink
        }

  @type conn :: Plug.Conn.t()
  @type plug_module :: Sink
  @type status_response :: :ok | {:error, term()}

  @type response :: {:ok, term()} | {:error, term()}
  @callback call(t()) :: response()

  def source("http" <> _ = uri) when is_binary(uri) do
    %__MODULE__{conn: Stow.Conn.new(uri), type: :source} |> run(:http)
  end

  def run(%{type: :source} = stow, :http), do: Stow.Source.Http.call(stow)

  @spec status(conn(), plug_module()) :: status_response()
  def status(conn, Sink) do
    get_in(conn.private, [:stow, Access.key!(:sink)]).status
  end

  def status(conn, Source) do
    get_in(conn.private, [:stow, Access.key!(:source)]).status
  end
end
