defmodule Arc.Actions.Store do
  defmacro __using__(_) do
    quote do
      def store(args, initial \\ nil, reducer \\ &(&1)), do: Arc.Actions.Store.store(__MODULE__, args, initial, reducer)
    end
  end

  def store(definition, {file, scope}, initial, reducer) when is_binary(file) or is_map(file) do
    put(definition, {Arc.File.new(file), scope}, initial, reducer)
  end

  def store(definition, filepath, initial, reducer) when is_binary(filepath) or is_map(filepath) do
    store(definition, {filepath, nil}, initial, reducer)
  end

  #
  # Private
  #

  defp put(_definition, {{:error, _msg}, _scope}, _initial, _reducer) do
    {:error, :invalid_file}
  end

  defp put(definition, {%Arc.File{}=file, scope}, initial, reducer) do
    case definition.validate({file, scope}) do
      true -> put_versions(definition, {file, scope}, initial, reducer)
      _    -> {:error, :invalid_file}
    end
  end

  defp put_versions(definition, {file, scope}, initial, reducer) do
    definition.__versions
    |> Enum.map(fn(r)    -> async_put_version(definition, r, {file, scope}) end)
    |> Enum.map(fn(task) -> Task.await(task, version_timeout) end)
    |> handle_responses(file.file_name, initial, reducer)
  end

  defp handle_responses(responses, filename, nil, _reducer) do
    errors = Enum.filter(responses, fn(resp) -> elem(resp, 0) == :error end) |> Enum.map(fn(err) -> elem(err, 1) end)
    if Enum.empty?(errors), do: {:ok, filename}, else: {:error, errors}
  end
  defp handle_responses(responses, filename, initial, reducer) do
    result = handle_responses(responses, filename, nil, nil)
    reduce_result = Enum.reduce(responses, initial, reducer)
    Tuple.append(result, reduce_result)
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
    case Arc.Processor.process(definition, version, {file, scope}) do
      {:error, error} -> {:error, error}
      {:ok, file} ->
        file_name = Arc.Definition.Versioning.resolve_file_name(definition, version, {file, scope})
        file      = %Arc.File{file | file_name: file_name}
        case definition.__storage.put(definition, version, {file, scope}) do
          {:ok, response}   -> {:ok, response, version, file}
          {:error, err_msg} -> {:error, err_msg, version, file}
        end
    end
  end
end
