defmodule Arc.File do
  defstruct [:path, :file_name, :binary]

  def temp_path do
    rand = Base.encode32(:crypto.rand_bytes(20))
    Path.join(System.tmp_dir, rand)
  end

  # Accepts a path
  def new(path) when is_binary(path) do
    case File.exists?(path) do
      true -> %Arc.File{ path: path, file_name: Path.basename(path) }
      false -> {:error, :no_file}
    end
  end

  def new(%{filename: filename, binary: binary}) do
    %Arc.File{ binary: binary, file_name: Path.basename(filename) }
  end

  # Accepts a map conforming to %Plug.Upload{} syntax
  def new(%{filename: filename, path: path}) do
    case File.exists?(path) do
      true -> %Arc.File{ path: path, file_name: filename }
      false -> {:error, :no_file}
    end
  end

  def ensure_path(file = %{path: path}) when is_binary(path), do: file
  def ensure_path(file = %{binary: binary}) when is_binary(binary), do: write_binary(file)

  defp write_binary(file) do
    path = temp_path()
    :ok = File.write!(path, file.binary)

    %__MODULE__{
      file_name: file.file_name,
      path: path
    }
  end
end
