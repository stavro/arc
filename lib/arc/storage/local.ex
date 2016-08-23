defmodule Arc.Storage.Local do
  def put(definition, version, {file, scope}) do
    destination_dir = definition.storage_dir(version, {file, scope})
    path = Path.join([local_dir, destination_dir, file.file_name])
    path |> Path.dirname() |> File.mkdir_p()
    File.copy!(file.path, path)
    {:ok, file.file_name}
  end

  def url(definition, version, file_and_scope, _options \\ []) do
    build_local_path(definition, version, file_and_scope)
  end

  def delete(definition, version, file_and_scope) do
    build_local_path(definition, version, file_and_scope)
    |> File.rm
  end

  defp build_local_path(definition, version, file_and_scope) do
    Path.join([
      local_dir,
      definition.storage_dir(version, file_and_scope),
      Arc.Definition.Versioning.resolve_file_name(definition, version, file_and_scope)
    ])
  end

  defp local_dir do
    Application.get_env(:arc, :local_dir) || ""
  end
end
