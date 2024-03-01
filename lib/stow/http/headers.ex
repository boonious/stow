defmodule Stow.Http.Headers do
  @moduledoc false
  defstruct req: [], resp: []
  @type t :: %__MODULE__{req: [{binary, binary}], resp: [{binary, binary}]}
end
