defprotocol Stow.ResponseHandler do
  @moduledoc ~S"""
  The `Stow.Response` protocol is responsible for
  converting various data sources response to the `Stow.Response.t()` struct.

  The only function that must be implemented is
  `to_response/1` which does the conversion.
  """

  @dialyzer {:nowarn_function, to_response: 1}

  @fallback_to_any true
  @spec to_response(term()) :: Stow.Response.t()
  def to_response(value)
end

defimpl Stow.ResponseHandler, for: Tuple do
  alias Stow.Response
  import Stow.Response

  # httpc response
  def to_response({:ok, {{[?H, ?T, ?T, ?P | _], status, _}, headers, body}}) do
    %Response{state: :ok}
    |> put_body(body |> IO.iodata_to_binary())
    |> put_status(status)
    |> put_headers(headers)
  end

  def to_response({:error, term}), do: %Stow.Response{state: {:error, term}}
end

defimpl Stow.ResponseHandler, for: Any do
  def to_response(_value), do: %Stow.Response{}
end
