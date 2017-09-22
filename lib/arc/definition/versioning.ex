defmodule Arc.Definition.Versioning do
  defmacro __using__(_) do
    quote do
      @versions [:original]

      # Invoke Arc.Definition.Versioning.__before_compile__/1 before
      # the module is compiled.
      @before_compile Arc.Definition.Versioning
    end
  end

  @doc """
  Gets destination filename even when extension changes due to transformation
  """
  def resolve_file_name(definition, version, {file, scope}) do
    name = definition.filename(version, {file, scope})
    conversion = definition.transform(version, {file, scope})

    case conversion do
      {_, _, ext} -> "#{name}.#{ext}"
       _          -> "#{name}#{Path.extname(file.file_name)}"
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @doc """
      By default, the transform function does nothing
      """
      def transform(_, _), 
      do: :noaction

      @doc """
      Returns a list of possible versions
      """
      def __versions, 
      do: @versions
    end
  end
end
