defmodule Arc.File do
  defstruct [:path, :file_name, :binary]

  def generate_temporary_path(file \\ nil) do
    extension = Path.extname((file && file.path) || "")
    file_name = Arc.UUID.generate() <> extension
    Path.join(System.tmp_dir, file_name)
  end

  # Given a remote file
  def new(remote_path = "http" <> _) do
    case save_file(remote_path) do
      {:ok, local_path} -> %Arc.File{path: local_path, file_name: Path.basename(remote_path)}
      :error -> {:error, :invalid_file_path}
    end
  end

  # Accepts a path
  def new(path) when is_binary(path) do
    case File.exists?(path) do
      true -> %Arc.File{path: path, file_name: Path.basename(path)}
      false -> {:error, :invalid_file_path}
    end
  end

  def new(%{filename: filename, binary: binary}) do
    %Arc.File{binary: binary, file_name: Path.basename(filename)}
  end

  # Accepts a map conforming to %Plug.Upload{} syntax
  def new(%{filename: filename, path: path}) do
    case File.exists?(path) do
      true -> %Arc.File{path: path, file_name: filename}
      false -> {:error, :invalid_file_path}
    end
  end

  def ensure_path(file = %{path: path}) when is_binary(path), do: file
  def ensure_path(file = %{binary: binary}) when is_binary(binary), do: write_binary(file)

  defp write_binary(file) do
    path = generate_temporary_path(file)
    :ok = File.write!(path, file.binary)

    %__MODULE__{
      file_name: file.file_name,
      path: path
    }
  end

  defp save_file(remote_path) when is_binary(remote_path) do
    local_path =
      generate_temporary_path()
      |> Kernel.<>(Path.extname(remote_path))

    case save_temp_file(local_path, remote_path) do
      :ok -> {:ok, local_path}
      _   -> :error
    end
  end

  defp save_temp_file(local_path, remote_path) do
    remote_file = get_remote_path(remote_path)

    case remote_file do
      {:ok, body} -> File.write(local_path, body)
      {:error, error} -> {:error, error}
    end
  end

  defp get_remote_path(remote_path) do
    case HTTPoison.get(remote_path) do
      {:ok, %{status_code: 200, body: body}} -> {:ok, body}
      other -> {:error, :invalid_file_path}
    end
  end
end
