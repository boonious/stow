defmodule Stow.Pipeline.SourceSink do
  @moduledoc false
  use Stow.Pipeline

  alias Plug.Conn
  alias Stow.Plug.{Sink, Source}

  import Stow.Plug.Utils, only: [update_private: 3]

  @fields [:source, :sink]

  plug(Source)
  plug(Sink)

  # TODO: passing opts to source/sink, default opts in source/sink
  @impl true
  def call(conn, opts) do
    opts = Keyword.validate!(opts, @fields)

    @fields
    |> Enum.map(&{&1, Keyword.get(opts, &1)})
    |> then(&set_private_fields(conn, &1))
    |> maybe_halt_pipeline()
    |> super(opts)
  end

  def set_private_fields(conn, []), do: conn

  def set_private_fields(conn, [{field, value} | rest]) do
    new_field_struct(field, value)
    |> then(&update_private(conn, field, &1))
    |> set_private_fields(rest)
  end

  defp new_field_struct(_field, nil), do: nil

  defp new_field_struct(field, value) do
    "#{field}"
    |> Macro.camelize()
    |> then(&Module.concat(Stow, &1))
    |> then(& &1.new(value))
  end

  defp maybe_halt_pipeline(%Conn{} = conn) do
    maybe_halt_pipeline(conn, conn.private, Map.has_key?(conn.private, :stow))
  end

  defp maybe_halt_pipeline(conn, private, true) do
    case private.stow do
      %{source: source, sink: sink} when source != nil and sink != nil -> conn
      %{source: nil} -> halt(conn)
      %{sink: nil} -> halt(conn)
    end
  end

  defp maybe_halt_pipeline(conn, _private, false), do: halt(conn)
end
