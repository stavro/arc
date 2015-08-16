defmodule Arc.Storage.Local do

  def put(definition, version, {file, scope}) do
    destination_dir = definition.storage_dir(version, {file, scope})
    File.mkdir_p(destination_dir)
    file_name = definition.filename(version, file)
    {:ok, _} = File.copy(file.path, Path.join(destination_dir, file_name))
    file_name
  end

  def url(definition, version, {file, scope}, options \\ []) do
    destination_dir = definition.storage_dir(version, {file, scope})
    file_name = definition.filename(version, file)
    Path.join(destination_dir, file_name)
  end

  def delete(definition, version, {file, scope}) do
    destination_dir = definition.storage_dir(version, {file, scope})
    file_name = definition.filename(version, file)
    File.rm(Path.join(destination_dir, file_name))
  end
end
