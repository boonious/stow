defmodule Stow.Source.Extras do
  @moduledoc false
  alias Stow.Http.Headers
  defstruct headers: %Headers{}
  @type t :: %__MODULE__{headers: Headers.t()}
end
