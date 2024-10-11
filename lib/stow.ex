defmodule Stow do
  @moduledoc false

  alias Stow.Conn

  @type response :: :ok | {:ok, term()} | {:error, term()}
  @callback call(Conn.t()) :: response()

  defmacro __using__(_opts) do
    quote do
      @behaviour Stow

      def call(%Stow.Conn{method: :get} = conn), do: Stow.Source.Http.call(conn)
      def call(%Stow.Conn{method: :put} = conn), do: Stow.Sink.File.call(conn)
      def call(%Stow.Conn{method: :delete} = conn), do: Stow.Sink.File.call(conn)

      defoverridable call: 1
    end
  end


  def source(uri, opts \\ []) when is_binary(uri) do
    {:source, %{Stow.Conn.new(uri, :get) | opts: opts}} |> run()
  end

  def sink(uri, data, opts \\ []) when is_binary(uri) do
    # needs put_body in Conn
    {:sink, %{Stow.Conn.new(uri, :put) | body: data, opts: opts}} |> run()
  end

  defp run({:source, conn}) do
    case conn.uri.scheme do
      "https" -> conn |> Stow.Source.Http.call()
      "http" -> conn |> Stow.Source.Http.call()
    end
  end

  defp run({:sink, conn}) do
    case conn.uri.scheme do
      "file" -> conn |> Stow.Sink.File.call()
    end
  end
end
