defmodule Arc.Storage.Local do
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

  def url(definition, version, file_and_scope, _options \\ []) do
    local_path = build_local_path(definition, version, file_and_scope)

    if host() == "" do
      Path.join "/", local_path
    else
      Path.join [host(), "/", local_path]
    end
  end

  def delete(definition, version, file_and_scope) do
    build_local_path(definition, version, file_and_scope)
    |> File.rm()
  end

  defp build_local_path(definition, version, file_and_scope) do
    Path.join([
      definition.storage_dir(version, file_and_scope),
      Arc.Definition.Versioning.resolve_file_name(definition, version, file_and_scope)
    ])
  end

  defp host do
    host_url = Application.get_env(:arc, :asset_host, "")

    case host_url do
      {:system, env_var} when is_binary(env_var) -> System.get_env(env_var)
      url -> url
    end
  end
end
