defmodule Stow.Adapter do
  @moduledoc false

  @callback dispatch(Stow.Conn.t()) :: Stow.response()

  defdelegate impl, to: Stow.Config, as: :adapter
  defdelegate impl(scheme), to: Stow.Config, as: :adapter
end
