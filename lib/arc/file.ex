defmodule Arc.File do
  defstruct [:path, :file_name, :binary]

  @doc """
  This function generates a temporary file path to save a file to
  """
  def generate_temporary_path(file \\ nil) do
    extension = Path.extname((file && file.path) || "")

    file_name =
      :crypto.strong_rand_bytes(20)
      |> Base.encode32()
      |> Kernel.<>(extension)

    Path.join(System.tmp_dir, file_name)
  end

  @doc """
  Extracts remote file and creates an %Arc.File{} struct

  Returns a %Arc.File{} on success.
  """
  def new(remote_path = "http" <> _) do
    uri = URI.parse(remote_path)
    filename = Path.basename(uri.path)

    case save_file(uri, filename) do
      {:ok, local_path} -> %Arc.File{path: local_path, file_name: filename}
      :error -> {:error, :invalid_file_path}
    end
  end

  @doc """
  Creates an %Arc.File{} struct directly from the given file path
  """
  def new(path) when is_binary(path) do
    case File.exists?(path) do
      true -> %Arc.File{path: path, file_name: Path.basename(path)}
      false -> {:error, :invalid_file_path}
    end
  end

  @doc """
  Creates an %Arc.File{} struct directly from the given file binary
  """
  def new(%{filename: filename, binary: binary}) do
    %Arc.File{binary: binary, file_name: Path.basename(filename)}
  end

  @doc """
  Accepts a map conforming to %Plug.Upload{} syntax and creates an %Arc.File{} struct
  """
  def new(%{filename: filename, path: path}) do
    case File.exists?(path) do
      true -> %Arc.File{path: path, file_name: filename}
      false -> {:error, :invalid_file_path}
    end
  end

  @doc """
  If %Arc.File{} contains `:binary`, this function saves the file 
  and replaces `:binary` with `:path`.
  """
  def ensure_path(file = %{path: path}) when is_binary(path), do: file
  def ensure_path(file = %{binary: binary}) when is_binary(binary), do: write_binary(file)

  # Creates file in a temporary location from given binary
  defp write_binary(file) do
    path = generate_temporary_path(file)
    :ok = File.write!(path, file.binary)

    %__MODULE__{
      file_name: file.file_name,
      path: path
    }
  end

  # Saves remote file in a temporary location and returns the tmp path
  defp save_file(uri, filename) do
    local_path =
      generate_temporary_path()
      |> Kernel.<>(Path.extname(filename))

    case save_temp_file(local_path, uri) do
      :ok -> {:ok, local_path}
      _ -> :error
    end
  end

  # Helper function for save_file/2 to get remote file
  defp save_temp_file(local_path, remote_path) do
    remote_file = get_remote_path(remote_path)

    case remote_file do
      {:ok, body} -> File.write(local_path, body)
      {:error, error} -> {:error, error}
    end
  end

  # Helper function to download the remote file
  #
  # hakney :connect_timeout - timeout used when establishing a connection, in milliseconds
  # hakney :recv_timeout - timeout used when receiving from a connection, in milliseconds
  # poison :timeout - timeout to establish a connection, in milliseconds
  # :backoff_max - maximum backoff time, in milliseconds
  # :backoff_factor - a backoff factor to apply between attempts, in milliseconds
  defp get_remote_path(remote_path) do
    options = [
      follow_redirect: true,
      recv_timeout: Application.get_env(:arc, :recv_timeout, 5_000),
      connect_timeout: Application.get_env(:arc, :connect_timeout, 10_000),
      timeout: Application.get_env(:arc, :timeout, 10_000),
      max_retries: Application.get_env(:arc, :max_retries, 3),
      backoff_factor: Application.get_env(:arc, :backoff_factor, 1000),
      backoff_max: Application.get_env(:arc, :backoff_max, 30_000),
    ]
    request(remote_path, options)
  end

  # Helper function to actually download the remote file using HTTPoison
  defp request(remote_path, options, tries \\ 0) do
    case HTTPoison.get(remote_path, [], options) do
      {:ok, %{status_code: 200, body: body}} -> {:ok, body}
      {:error, %{reason: :timeout}} ->
        case retry(tries, options) do
          {:ok, :retry} -> request(remote_path, options, tries + 1)
          {:error, :out_of_tries} -> {:error, :timeout}
        end

      _ -> {:error, :arc_httpoison_error}
    end
  end

  # Helper function to retry upon failure to acquire remote file
  defp retry(tries, options) do
    cond do
      tries < options[:max_retries] ->
        backoff = round(options[:backoff_factor] * :math.pow(2, tries - 1))
        backoff = :erlang.min(backoff, options[:backoff_max])
        :timer.sleep(backoff)
        {:ok, :retry}

      true -> {:error, :out_of_tries}
    end
  end
end
