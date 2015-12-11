defmodule Arc.Transformations.Convert do
  def apply(file, args) do
    new_path = temp_path

    System.cmd("convert",
      ~w(#{file.path} #{args} #{String.replace(new_path, " ", "\\ ")}),
      stderr_to_stdout: true)
    |> handle_exit_code

    %Arc.File{file | path: new_path}
  end

  defp handle_exit_code({_, 0}), do: :ok
  defp handle_exit_code({error_message, exit_code}) do
    raise Arc.ConvertError, message: error_message, exit_code: exit_code
  end

  defp temp_path do
    rand = Base.encode32(:crypto.rand_bytes(20))
    Path.join(System.tmp_dir, rand)
  end
end
