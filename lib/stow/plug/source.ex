defmodule Stow.Plug.Source do
  @moduledoc false
  @behaviour Plug

  alias Stow.Plug.Utils
  alias Stow.Source

  import Utils,
    only: [
      fetch_opts: 2,
      fetch_uri: 3,
      set_private_opts: 3,
      set_req_params: 2,
      update_status: 3
    ]

  @plug_opts [:uri, :options]
  @schemes ["http", "https"]

  @impl true
  def init(opts), do: validate_opts(opts)

  @impl true
  def call(conn, opts) do
    with {:ok, conn} <- set_private_opts(conn, :source, opts),
         {:ok, uri, conn} <- fetch_uri(conn, opts, {:source, @schemes}),
         conn <- set_req_params(conn, uri),
         {:ok, conn} <- source_data(conn) do
      conn
    else
      {:error, conn} -> conn
    end
  end

  # TODO: validate options in %{"scheme" => keyword()} format
  defp validate_opts(opts), do: Keyword.validate!(opts, @plug_opts)

  defp source_data(conn) do
    normalise_scheme_name(conn.scheme)
    |> Kernel.<>("_source")
    |> Macro.camelize()
    |> then(fn source -> Module.concat(Source, source) end)
    |> apply(:get, [conn, fetch_opts(conn.private.stow.source.options, :source)])
    |> update_status(conn, :source)
  end

  defp normalise_scheme_name(scheme) when scheme in [:http, :https], do: "http"
end
