defmodule Arc.Definition.Versioning do
  defmacro __using__(_) do
    quote do
      @versions [:original]
      @before_compile Arc.Definition.Versioning
    end
  end

  def resolve_file_name(definition, version, {file, scope}) do
    name = definition.filename(version, {file, scope})
    conversion = definition.transform(version, {file, scope})

    case conversion do
      {:noaction} -> "#{name}#{Path.extname(file.file_name)}"
      {:convert, args} ->
        extension = case Regex.run(~r/-format[ ]*(\w*)/, args) do
          nil -> "#{name}#{Path.extname(file.file_name)}"
          [_, ext] -> "#{name}.#{ext}"
        end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def transform(_, _), do: {:noaction}
      def __versions, do: @versions
    end
  end
end
