defmodule Arc.Actions.Url do
  defmacro __using__(_) do
    quote do
      def urls(file, options \\ []) do
        Enum.into __MODULE__.__versions, %{}, fn(r) ->
          {r, __MODULE__.url(file, r, options)}
        end
      end

      def url(file), do: url(file, nil)
      def url(file, options) when is_list(options), do: url(file, nil, options)
      def url(file, version), do: url(file, version, [])
      def url(file, version, options), do: Arc.Actions.Url.url(__MODULE__, file, version, options)

      defoverridable [{:url, 3}]
    end
  end

  # Apply default version if not specified
  def url(definition, file, nil, options),
    do: url(definition, file, Enum.at(definition.__versions, 0), options)

  # Transform standalone file into a tuple of {file, scope}
  def url(definition, file, version, options) when is_binary(file) or is_map(file) or is_nil(file),
    do: url(definition, {file, nil}, version, options)

  # Transform file-path into a map with a file_name key
  def url(definition, {file, scope}, version, options) when is_binary(file) do
    url(definition, {%{file_name: file}, scope}, version, options)
  end

  def url(definition, {file, scope}, version, options) do
    build(definition, version, {file, scope}, options)
  end

  #
  # Private
  #

  defp build(definition, version, {nil, scope}, _options) do
    definition.default_url(version, scope)
  end

  defp build(definition, version, file_and_scope, options) do
    case Arc.Definition.Versioning.resolve_file_name(definition, version, file_and_scope) do
      nil -> nil
      _ ->
        definition.__storage.url(definition, version, file_and_scope, options)
    end
  end
end
