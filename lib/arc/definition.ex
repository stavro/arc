defmodule Arc.Definition do
  defmacro __using__(_options) do
    quote do
      use Arc.Definition.Versioning
      use Arc.Definition.Storage

      use Arc.Actions.Store
      use Arc.Actions.Delete
      use Arc.Actions.Url
    end
  end
end
