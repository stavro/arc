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

  #
  # Private
  #

  defp put(_definition, { error = {:error, _msg}, _scope}), do: error
  defp put(definition, {%Arc.File{}=file, scope}) do
    case definition.validate({file, scope}) do
      true -> put_versions(definition, {file, scope})
      _    -> {:error, :invalid_file}
    end
  end

  defp put_versions(definition, {file, scope}) do
    if definition.async do
      definition.__versions
      |> Enum.map(fn(r)    -> async_process_version(definition, r, {file, scope}) end)
      |> Enum.map(fn(task) -> Task.await(task, version_timeout()) end)
      |> ensure_all_success
      |> Enum.map(fn({v, r})    -> async_put_version(definition, v, {r, scope}) end)
      |> Enum.map(fn(task) -> Task.await(task, version_timeout()) end)
      |> handle_responses(file.file_name)
    else
      definition.__versions
      |> Enum.map(fn(version) -> process_version(definition, version, {file, scope}) end)
      |> ensure_all_success
      |> Enum.map(fn({version, result}) -> put_version(definition, version, {result, scope}) end)
      |> handle_responses(file.file_name)
    end
  end

  defp ensure_all_success(responses) do
    errors = Enum.filter(responses, fn({_version, resp}) -> elem(resp, 0) == :error end)
    if Enum.empty?(errors), do: responses, else: errors
  end

  defp handle_responses(responses, filename) do
    errors = Enum.filter(responses, fn(resp) -> elem(resp, 0) == :error end) |> Enum.map(fn(err) -> elem(err, 1) end)
    if Enum.empty?(errors), do: {:ok, filename}, else: {:error, errors}
  end

  defp version_timeout do
    Application.get_env(:arc, :version_timeout) || 15_000
  end

  defp async_process_version(definition, version, {file, scope}) do
    Task.async(fn ->
      process_version(definition, version, {file, scope})
    end)
  end

  defp async_put_version(definition, version, {result, scope}) do
    Task.async(fn ->
      put_version(definition, version, {result, scope})
    end)
  end

  defp process_version(definition, version, {file, scope}) do
    {version, Arc.Processor.process(definition, version, {file, scope})}
  end

  defp put_version(definition, version, {result, scope}) do
    case result do
      {:error, error} -> {:error, error}
      {:ok, nil} -> {:ok, nil}
      {:ok, file} ->
        file_name = Arc.Definition.Versioning.resolve_file_name(definition, version, {file, scope})
        file      = %Arc.File{file | file_name: file_name}
        result = definition.__storage.put(definition, version, {file, scope})
        result
    end
  end
end
