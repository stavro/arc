defmodule Arc.Transformations.Convert do
  def apply(file, args) do
    new_path = temp_path

    System.cmd("convert",
      ~w(#{file.path} #{args} #{String.replace(new_path, " ", "\\ ")}),
      stderr_to_stdout: true)

    %Arc.File{file | path: new_path}
  end

  defp temp_path do
    rand = Base.encode32(:crypto.rand_bytes(20))
    Path.join(System.tmp_dir, rand)
  end
end
