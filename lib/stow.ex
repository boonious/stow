defmodule Stow do
  @moduledoc false

  alias Stow.Conn

  @type response :: :ok | {:ok, term()} | {:error, term()}
  @callback call(Conn.t()) :: response()

  def source("http" <> _ = uri, opts \\ []) when is_binary(uri) do
    {:source, %{Stow.Conn.new(uri, :get) | opts: opts}} |> run()
  end

  def sink("file:" <> _ = uri, data, opts \\ []) when is_binary(uri) do
    # needs put_body in Conn
    {:sink, %{Stow.Conn.new(uri, :put) | body: data, opts: opts}} |> run()
  end

  def run({:source, conn}) do
    case conn.uri.scheme do
      "https" -> conn |> Stow.Source.Http.call()
      "http" -> conn |> Stow.Source.Http.call()
    end
  end

  def run({:sink, conn}) do
    case conn.uri.scheme do
      "file" -> conn |> Stow.Sink.File.call()
    end
  end
end
