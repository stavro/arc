defmodule Arc.Storage.Local do

  def put(definition, version, {file, scope}) do
    destination_dir = definition.storage_dir(version, {file, scope})
    {:ok, binary} = File.read(file.path)
    File.write!(Path.join(destination_dir, file.file_name), binary)
    file.file_name
  end

  def url(definition, version, {file, scope}, options \\ []) do
    destination_dir = definition.storage_dir(version, {file, scope})
    Path.join(destination_dir, file.file_name)
  end

  def delete(definition, version, {file, scope}) do
    destination_dir = definition.storage_dir(version, {file, scope})
    File.rm(Path.join(destination_dir, file.file_name))
  end
end
