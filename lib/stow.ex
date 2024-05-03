defmodule Stow do
  @moduledoc false

  alias Stow.Plug.Sink
  alias Stow.Plug.Source

  @type conn :: Plug.Conn.t()
  @type plug_module :: Sink | Source
  @type status_response :: :ok | {:error, term()}

  @spec status(conn(), plug_module()) :: status_response()
  def status(conn, Sink) do
    get_in(conn.private, [:stow, Access.key!(:sink)]).status
  end

  def status(conn, Source) do
    get_in(conn.private, [:stow, Access.key!(:source)]).status
  end
end
