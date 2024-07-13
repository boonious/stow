defmodule Stow.Response do
  @moduledoc """
  Struct containing a standardised response from various data sources.
  """

  defstruct [:body, :headers, :state, :status]

  @type t :: %__MODULE__{
          body: nil | iodata(),
          headers: nil | [{binary(), binary()}],
          status: nil | pos_integer(),
          state: nil | :ok | {:error, term()}
        }

  def put_body(response, body) when is_binary(body) do
    %{response | body: body}
  end

  def put_body(response, body) when is_list(body) do
    %{response | body: if(IO.iodata_length(body) > 0, do: body, else: nil)}
  end

  def put_headers(response, [{k, v} | _] = headers) when is_binary(k) and is_binary(v) do
    %{response | headers: headers}
  end

  def put_headers(response, [{k, v} | _] = headers)
      when is_list(k) and is_list(v) and is_integer(hd(k)) and is_integer(hd(v)) do
    %{response | headers: headers |> Enum.map(fn {k, v} -> {to_string(k), to_string(v)} end)}
  end

  def put_status(response, status) when is_integer(status) do
    %{response | status: status}
  end
end
