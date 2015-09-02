defmodule Arc.File do
  defstruct [:path, :file_name, :binary]

  # Accepts a path
  def new(path) when is_binary(path) do
    case File.exists?(path) do
      true -> %Arc.File{ path: path, file_name: Path.basename(path) }
      false -> {:error, :no_file}
    end
  end

  def new(binary, filename) do
     %Arc.File{ binary: binary, file_name: Path.basename(filename) }
  end

  # Accepts a map conforming to %Plug.Upload{} syntax
  def new(%{filename: filename, path: path}) do
    case File.exists?(path) do
      true -> %Arc.File{ path: path, file_name: filename }
      false -> {:error, :no_file}
    end
  end
end
