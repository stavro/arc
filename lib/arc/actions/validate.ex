defmodule Arc.Actions.Validate do

  defmacro __using__(_) do
    quote do
      def valid?(args), do: Arc.Actions.Validate.valid?(__MODULE__, args)
    end
  end

  def valid?(definition, {file, scope}) when is_binary(file) or is_map(file) do
    case Arc.File.new(file) do
      {:error, error} ->
        {:error, error}
      file ->
        case definition.validate({file, scope}) do
          true -> {:ok}
          _    -> {:error, :invalid_file}
        end
      end
  end

  def valid?(definition, filepath) when is_binary(filepath) or is_map(filepath) do
    valid?(definition, {filepath, nil})
  end
end
