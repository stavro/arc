defmodule Arc.Storage.Local do
  @doc """
  Place the file in the local directory as defined by the __storage function 
  """
  def put(definition, version, {file, scope}) do
    destination_dir = definition.storage_dir(version, {file, scope})
    path = Path.join(destination_dir, file.file_name)
    path |> Path.dirname() |> File.mkdir_p!()

    if binary = file.binary do
      File.write!(path, binary)
    else
      File.copy!(file.path, path)
    end

    {:ok, file.file_name}
  end

  @doc """
  Get a url to the local path
  """
  def url(definition, version, file_and_scope, _options \\ []) do
    local_path = build_local_path(definition, version, file_and_scope)

    url = if String.starts_with?(local_path, "/") do
      local_path
    else
      "/" <> local_path
    end

    url |> URI.encode()
  end

  @doc """
  Delete the specified file
  """
  def delete(definition, version, file_and_scope) do
    build_local_path(definition, version, file_and_scope)
    |> File.rm()
  end

  # Create a local path for storage from the given definition and version
  defp build_local_path(definition, version, file_and_scope) do
    Path.join([
      definition.storage_dir(version, file_and_scope),
      Arc.Definition.Versioning.resolve_file_name(definition, version, file_and_scope)
    ])
  end
end
