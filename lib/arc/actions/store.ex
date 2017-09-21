defmodule Arc.Actions.Store do
  defmacro __using__(_) do
    quote do
      def store(args), do: Arc.Actions.Store.store(__MODULE__, args)
    end
  end

  @doc """
  This calls the put/3 to store the file under the named scope.
  """
  def store(definition, {file, scope}) when is_binary(file) or is_map(file) do
    put(definition, {Arc.File.new(file), scope})
  end

  @doc """
  Stores file without scope

  This calls the store/2 with a `nil` scope.
  """
  def store(definition, filepath) when is_binary(filepath) or is_map(filepath) do
    store(definition, {filepath, nil})
  end

  @doc """
  Validates file and on success call put_versions/2
  """
  defp put(_definition, { error = {:error, _msg}, _scope}), do: error
  defp put(definition, {%Arc.File{}=file, scope}) do
    case definition.validate({file, scope}) do
      true -> put_versions(definition, {file, scope})
      _    -> {:error, :invalid_file}
    end
  end

  @doc """
  Creates all versions of the given file and calls handle_responses/2
  """
  defp put_versions(definition, {file, scope}) do
    if definition.async do
      definition.__versions
      |> Enum.map(fn(r)    -> async_put_version(definition, r, {file, scope}) end)
      |> Enum.map(fn(task) -> Task.await(task, version_timeout()) end)
      |> handle_responses(file.file_name)
    else
      definition.__versions
      |> Enum.map(fn(version) -> put_version(definition, version, {file, scope}) end)
      |> handle_responses(file.file_name)
    end
  end

  @doc """
  Checks if all versions were created successfully
  """
  defp handle_responses(responses, filename) do
    errors = 
      Enum.filter(responses, fn(resp) -> elem(resp, 0) == :error end) 
      |> Enum.map(fn(err) -> elem(err, 1) end)
    
    if Enum.empty?(errors), 
    do: {:ok, filename}, 
    else: {:error, errors}
  end

  @doc """
  Get timeout configuration from application config or default to 15s
  """
  defp version_timeout do
    Application.get_env(:arc, :version_timeout) || 15_000
  end

  @doc """
  A wrapper to generate versions asynchronously
  """
  defp async_put_version(definition, version, {file, scope}) do
    Task.async(fn ->
      put_version(definition, version, {file, scope})
    end)
  end

  @doc """
  Calls Arc.Processor.process/3 to actually generate all versions
  """
  defp put_version(definition, version, {file, scope}) do
    case Arc.Processor.process(definition, version, {file, scope}) do
      {:error, error} -> {:error, error}
      {:ok, file} ->
        file_name = Arc.Definition.Versioning.resolve_file_name(definition, version, {file, scope})
        file      = %Arc.File{file | file_name: file_name}
        definition.__storage.put(definition, version, {file, scope})
    end
  end
end
