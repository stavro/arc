defmodule Arc.Actions.Store do
  defmacro __using__(_) do
    quote do
      def store(args), do: Arc.Actions.Store.store(__MODULE__, args)
    end
  end

  def store(definition, {file, scope}) when is_binary(file) or is_map(file) do
    put(definition, {Arc.File.new(file), scope})
  end

  def store(definition, filepath) when is_binary(filepath) or is_map(filepath) do
    store(definition, {filepath, nil})
  end

  def remove(definition, {file, scope}) when is_binary(file) or is_map(file) do
    delete(definition, {Arc.File.new(file), scope})
  end

  def remove(definition, filepath) when is_binary(filepath) or is_map(filepath) do
    remove(definition, {filepath, nil})
  end

  #
  # Private
  #

  defp put(definition, {{:error, msg}, scope}) do
    {:error, :invalid_file}
  end

  defp put(definition, {%Arc.File{}=file, scope}) do
    case definition.validate({file, scope}) do
      true ->
        put_versions(definition, {file, scope})
        {:ok, file.file_name}
      _    -> 
        {:error, :invalid_file}
    end
  end

  defp put_versions(definition, {file, scope}) do
    definition.__versions
    |> Enum.map(fn(r)     -> async_put_version(definition, r, {file, scope}) end)
    |> Enum.each(fn(task) -> Task.await(task, version_timeout) end)
  end

  defp version_timeout do
    Application.get_env(:arc, :version_timeout) || 15_000
  end

  defp async_put_version(definition, version, {file, scope}) do
    Task.async(fn ->
      put_version(definition, version, {file, scope})
    end)
  end

  defp put_version(definition, version, {file, scope}) do
    file      = Arc.Processor.process(definition, version, {file, scope})
    file_name = Arc.Definition.Versioning.resolve_file_name(definition, version, {file, scope})
    file      = %Arc.File{file | file_name: file_name}
    definition.__storage.put(definition, version, {file, scope})
  end

  defp delete(definition, {{:error, msg}, scope}) do
    {:error, :invalid_file}
  end

  defp delete(definition, {%Arc.File{}=file, scope}) do
    case definition.validate({file, scope}) do
      true -> 
        delete_versions(definition, {file, scope})
        {:ok, file.file_name}
      _    -> 
        {:error, :invalid_file}
    end
  end

  defp delete_versions(definition, {file, scope}) do
    definition.__versions
    |> Enum.map(fn(r)     -> async_delete_version(definition, r, {file, scope}) end)
    |> Enum.each(fn(task) -> Task.await(task, version_timeout) end)
  end

  defp async_delete_version(definition, version, {file, scope}) do
    Task.async(fn ->
      delete_version(definition, version, {file, scope})
    end)
  end

  defp delete_version(definition, version, {file, scope}) do
    file      = Arc.Processor.process(definition, version, {file, scope})
    file_name = Arc.Definition.Versioning.resolve_file_name(definition, version, {file, scope})
    file      = %Arc.File{file | file_name: file_name}
    definition.__storage.delete(definition, version, {file, scope})
  end
end
