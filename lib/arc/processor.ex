defmodule Arc.Processor do
  def process(definition, version, {file, scope}) do
    transform = definition.transform(version, {file, scope})
    apply_transformation(file, transform)
  end

  defp apply_transformation(_, :skip), do: {:ok, nil}
  defp apply_transformation(file, :noaction), do: {:ok, file}
  defp apply_transformation(file, {:noaction}), do: {:ok, file} # Deprecated
  defp apply_transformation(file, {cmd, conversion, _}) do
    apply_transformation(file, {cmd, conversion})
  end

  defp apply_transformation(file, {cmd, conversion}) do
    Arc.Transformations.Convert.apply(cmd, Arc.File.ensure_path(file), conversion)
  end
end
