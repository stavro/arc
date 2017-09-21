defmodule Arc.Processor do
  @doc """
  Generates the new version by calling apply_transform/2
  """
  def process(definition, version, {file, scope}) do
    transform = definition.transform(version, {file, scope})
    apply_transformation(file, transform)
  end

  @doc """
  Apply given transformation, including no transformation
  """
  defp apply_transformation(file, :noaction), do: {:ok, file}
  defp apply_transformation(file, {:noaction}), do: {:ok, file} # Deprecated
  defp apply_transformation(file, {cmd, conversion, _}) do
    apply_transformation(file, {cmd, conversion})
  end
  # Call Arc.Transformations.Convert.apply to apply transformation through cmd
  defp apply_transformation(file, {cmd, conversion}) do
    Arc.Transformations.Convert.apply(cmd, Arc.File.ensure_path(file), conversion)
  end
end
