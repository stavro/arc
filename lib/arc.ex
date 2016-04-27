defmodule Arc do
  defmacro __using__(_opts) do
    quote do
      use Arc.Definition
    end
  end
end
