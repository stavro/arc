defmodule Arc.Processor do
  def process(definition, version, {file, scope}) do
    transform = definition.transform(version, {file, scope})
    apply_transformation(file, transform, scope)
  end

  defp apply_transformation(file, :noaction, _), do: {:ok, file}
  defp apply_transformation(file, {:noaction}, _), do: {:ok, file} # Deprecated
  defp apply_transformation(file, {cmd, conversion, _}, format) do
    apply_transformation(file, {cmd, conversion}, format)
  end

  defp apply_transformation(file, {cmd, conversion}, format) do
    Arc.Transformations.Convert.apply(cmd, Arc.File.ensure_path(file), conversion, format)
  end
end
