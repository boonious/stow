defmodule Stow.URI do
  defmodule MalformedURIError do
    defexception message: "invalid file uri"

    def exception(uri), do: %MalformedURIError{message: "invalid file uri (#{inspect(uri)})"}
  end

  @moduledoc false

  defstruct [:host, :port, :scheme, path: "", query: ""]

  @type t :: %__MODULE__{
          host: nil | IO.chardata(),
          path: nil | IO.chardata(),
          port: nil | :inet.port_number(),
          query: nil | IO.chardata() | map(),
          scheme: binary()
        }

  # using URI to parse binary uri for now
  def new(uri) when is_binary(uri), do: URI.new!(uri) |> new()

  def new(%URI{} = uri) do
    %__MODULE__{
      host: uri.host,
      path: uri.path,
      port: uri.port,
      query: uri.query,
      scheme: uri.scheme
    }
  end

  def to_iolist(%__MODULE__{} = uri) do
    [
      uri.scheme,
      "://",
      uri.host,
      ":",
      if(is_integer(uri.port), do: "#{uri.port}", else: ""),
      if(uri.path, do: uri.path, else: ""),
      if(uri.query == "" or uri.query == nil, do: "", else: ["?", uri.query])
    ]
  end

  defimpl String.Chars, for: Stow.URI do
    def to_string(uri) do
      Stow.URI.to_iolist(uri) |> IO.iodata_to_binary()
    end
  end
end
