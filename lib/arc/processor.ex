defmodule Arc.Processor do
  def process(definition, version, {file, scope}) do
    apply_transformation file, definition.transform(version, {file, scope})
  end

  defp apply_transformation(file, {:noaction}) do
    file
  end

  defp apply_transformation(file, {cmd, conversion, _}) do
    apply_transformation(file,{cmd, conversion})
  end

  defp apply_transformation(file, {cmd, conversion}) do
    Arc.Transformations.Convert.apply(cmd, file, conversion)
  end
end
