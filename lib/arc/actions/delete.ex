defmodule Arc.Actions.Delete do
  defmacro __using__(_) do
    quote do
      def delete(args), do: Arc.Actions.Delete.delete(__MODULE__, args)
      
      defoverridable [{:delete, 1}]
    end
  end

  def delete(definition, {filepath, scope}) when is_binary(filepath) do
    do_delete(definition, {%{file_name: filepath}, scope})
  end

  def delete(definition, filepath) when is_binary(filepath) do
    do_delete(definition, {%{file_name: filepath}, nil})
  end

  #
  # Private
  #

  defp version_timeout do
    Application.get_env(:arc, :version_timeout) || 15_000
  end

  defp do_delete(definition, {file, scope}) do
    if definition.async do
      definition.__versions
      |> Enum.map(fn(r)     -> async_delete_version(definition, r, {file, scope}) end)
      |> Enum.each(fn(task) -> Task.await(task, version_timeout()) end)
    else
      definition.__versions
      |> Enum.map(fn(version) -> delete_version(definition, version, {file, scope}) end)
    end
    :ok
  end

  defp async_delete_version(definition, version, {file, scope}) do
    Task.async(fn -> delete_version(definition, version, {file, scope}) end)
  end

  defp delete_version(definition, version, {file, scope}) do
    definition.__storage.delete(definition, version, {file, scope})
  end
end
