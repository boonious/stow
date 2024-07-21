defmodule Stow.Sink.File do
  defmodule MalformedURIError do
    defexception message: "invalid file uri"

    def exception(uri), do: %MalformedURIError{message: "invalid file uri (#{inspect(uri)})"}
  end

  @moduledoc """
  A sink for putting and deleting local files.
  """

  @behaviour Stow

  @doc """
  Write or delete a local file given a `Stow.Conn.t()` connection.
  """
  @impl true
  def call(%Stow{conn: %{method: :put} = conn, type: :sink} = stow) do
    case {conn.uri.path, conn.uri.scheme} do
      {path, "file"} when path != nil -> conn |> stow.conn.adapter.dispatch()
      _ -> raise(Stow.URI.MalformedURIError.exception(conn.uri))
    end
  end

  @impl true
  def call(%Stow{conn: %{method: :delete} = conn, type: :sink} = stow) do
    conn |> stow.conn.adapter.dispatch()
  end
end
