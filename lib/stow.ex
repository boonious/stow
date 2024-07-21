defmodule Stow do
  @moduledoc false

  defstruct [:conn, :type]

  @type t :: %__MODULE__{
          conn: Stow.Conn.t(),
          type: :source | :sink
        }

  @type response :: :ok | {:ok, term()} | {:error, term()}
  @callback call(t()) :: response()

  def source("http" <> _ = uri) when is_binary(uri) do
    %__MODULE__{conn: Stow.Conn.new(uri), type: :source} |> run()
  end

  def sink("file:" <> _ = uri, data) when is_binary(uri) do
    # needs put_body in Conn
    conn = Stow.Conn.new(uri, :put)
    %__MODULE__{conn: %{conn | body: data}, type: :sink} |> run()
  end

  def run(%{type: :source} = stow) do
    case stow.conn.uri.scheme do
      "https" -> stow |> Stow.Source.Http.call()
      "http" -> stow |> Stow.Source.Http.call()
    end
  end

  def run(%{type: :sink} = stow) do
    case stow.conn.uri.scheme do
      "file" -> stow |> Stow.Sink.File.call()
    end
  end
end
