defmodule Arc.Transformations.Convert do
  def apply(cmd, file, args) do
    new_path = temp_path()
    args     = if is_function(args), do: args.(file.path, new_path), else: "#{file.path} #{args} #{new_path}"
    program  = to_string(cmd)

    ensure_executable_exists!(program)

    System.cmd(program, args_list(args), stderr_to_stdout: true)
      |> handle_exit_code!

    %Arc.File{file | path: new_path}
  end

  defp args_list(args) when is_list(args), do: args
  defp args_list(args), do: ~w(#{args})

  defp ensure_executable_exists!(program) do
    unless System.find_executable(program) do
      raise Arc.MissingExecutableError, message: program
    end
  end

  defp handle_exit_code!({_, 0}), do: :ok
  defp handle_exit_code!({error_message, exit_code}) do
    raise Arc.ConvertError, message: error_message, exit_code: exit_code
  end

  defp temp_path() do
    rand = Base.encode32(:crypto.rand_bytes(20))
    Path.join(System.tmp_dir, rand)
  end
end
