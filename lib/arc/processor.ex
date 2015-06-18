defmodule Arc.Processor do
  def process(definition, version, {file, scope}) do
    apply_transformation file, definition.transform(version, {file, scope})
  end

  defp apply_transformation(file, {:noaction}) do
    file
  end

  defp apply_transformation(file, {:convert, conversion}) do
    Arc.Transformations.Convert.apply(file, conversion)
  end
end
