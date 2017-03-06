defmodule Arc.Storage.Filesystem do
  @moduledoc """
  Store files anywhere in the filesystem

  ## Config

      config :arc,
        storage: Arc.Storage.Filesystem,
        upload_dir: {:system, "UPLOAD_DIR"}

      config :arc,
        storage: Arc.Storage.Filesystem,
        upload_dir: "uploads"
  """
  
  def put(definition, version, {file, scope}) do
    upload_dir = get_upload_dir()
    relative_path = definition.storage_dir(version, {file, scope})
    path = Path.join([upload_dir, relative_path, file.file_name])
    path |> Path.dirname() |> File.mkdir_p!()

    if binary = file.binary do
      File.write!(path, binary)
    else
      File.copy!(file.path, path)
    end

    {:ok, file.file_name}
  end

  def url(definition, version, file_and_scope, _options \\ []) do
    absolute_path = build_absolute_path(definition, version, file_and_scope)

    # strip upload dir from full path
    relative_path = Path.relative_to(absolute_path, get_upload_dir())

    if String.starts_with?(relative_path, "/") do
      relative_path
    else
      "/" <> relative_path
    end
  end

  def delete(definition, version, file_and_scope) do
    build_absolute_path(definition, version, file_and_scope)
    |> File.rm()
  end

  defp build_absolute_path(definition, version, file_and_scope) do
    Path.join([
      get_upload_dir(),
      definition.storage_dir(version, file_and_scope),
      Arc.Definition.Versioning.resolve_file_name(definition, version, file_and_scope)
    ])
  end

  def get_upload_dir() do
    case Application.fetch_env!(:arc, :upload_dir) do
      {:system, env} when not is_nil(env) ->
        # todo: make sure path is not nil
        System.get_env(env)
      path when not is_nil(path) ->
        path
    end
  end

end