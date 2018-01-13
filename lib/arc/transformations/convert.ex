defmodule Arc.Transformations.Convert do
  def apply(cmd, file, args, format) do
    extension = if format, do: ".#{ format}", else:  nil
    new_path = Arc.File.generate_temporary_path(file, extension)
    args     = if is_function(args), do: args.(file.path, new_path), else: [file.path | (String.split(args, " ") ++  [new_path])]
    args     = if is_binary(args), do:  String.split(args, " ", trim: true), else: args
    verbose_args = List.insert_at(args, -2, "-verbose")

    program  = to_string(cmd)

    ensure_executable_exists!(program)

    case System.cmd(program, args_list(verbose_args), stderr_to_stdout: true) do
      {output, 0} ->
        handle_success(output, file, new_path, extension)
      {error_message, _exit_code} ->
        {:error, error_message}
    end
  end

  defp handle_success(files_generated, file, new_path, extension) do
    out = String.split(files_generated, "\n", trim: true)
    case length(out) do
      n when n <= 1 -> {:ok, %Arc.File{file | path: new_path}}
      _ -> {:ok, output_for_multiple_files(out, file, new_path, extension)}
    end
  end

  defp output_for_multiple_files(files_created, file, new_path, extension) do
    Enum.with_index(files_created)
    |> Enum.map(fn({response, idx}) ->
      path_with_index = String.replace(new_path, ~r/#{extension}/, "-#{idx}#{extension}")
      %Arc.File{file | path: path_with_index}
    end)
  end

  defp args_list(args) when is_list(args), do: args
  defp args_list(args), do: ~w(#{args})

  defp ensure_executable_exists!(program) do
    unless System.find_executable(program) do
      raise Arc.MissingExecutableError, message: program
    end
  end
end


