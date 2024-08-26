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
  Put or delete a local file given a `Stow.Conn.t()` connection.
  """
  @impl true
  def call(%Stow.Conn{method: :put} = conn) do
    case {conn.uri.path, conn.uri.scheme} do
      {path, "file"} when path != nil -> conn |> conn.adapter.dispatch()
      _ -> raise(Stow.URI.MalformedURIError.exception(conn.uri))
    end
  end

  @impl true
  def call(%Stow.Conn{method: :delete} = conn) do
    conn |> conn.adapter.dispatch()
  end
end
