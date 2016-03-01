defmodule ArcTest.Processor do
  use ExUnit.Case, async: false
  @img "test/support/image.png"

  defmodule DummyDefinition do
    use Arc.Actions.Store
    use Arc.Definition.Storage

    def validate({file, _}), do: String.ends_with?(file.file_name, ".png")
    def transform(:original, _), do: {:noaction}
    def transform(:thumb, _), do: {:convert, "-strip -thumbnail 10x10"}
    def transform(:med, _), do: {:convert, fn(in_path, out_path) -> "#{in_path} -strip -thumbnail 10x10 #{out_path}" end, :jpg}
    def __versions, do: [:original, :thumb]
  end

  defmodule BrokenDefinition do
    use Arc.Actions.Store
    use Arc.Definition.Storage

    def validate({file, _}), do: String.ends_with?(file.file_name, ".png")
    def transform(:original, _), do: {:noaction}
    def transform(:thumb, _), do: {:convert, "-strip -invalidTransformation 10x10"}
    def __versions, do: [:original, :thumb]
  end

  test "returns the original path for {:noaction} transformations" do
    assert Arc.Processor.process(DummyDefinition, :original, {Arc.File.new(@img), nil}).path == @img
  end

  test "transforms a copied version of file according to the specified transformation" do
    new_file = Arc.Processor.process(DummyDefinition, :thumb, {Arc.File.new(@img), nil})
    assert new_file.path != @img
    assert "128x128" == geometry(@img) #original file untouched
    assert "10x10" == geometry(new_file.path)
    cleanup(new_file.path)
  end

  test "transforms a copied version of file according to the specified function transformation" do
    new_file = Arc.Processor.process(DummyDefinition, :med, {Arc.File.new(@img), nil})
    assert new_file.path != @img
    assert "128x128" == geometry(@img) #original file untouched
    assert "10x10" == geometry(new_file.path)
    cleanup(new_file.path)
  end

  test "raises an error in an invalid transformation" do
    assert_raise Arc.ConvertError, ~r"unrecognized option", fn ->
      Arc.Processor.process(BrokenDefinition, :thumb, {Arc.File.new(@img), nil})
    end
  end

  defp geometry(path) do
    {identify, 0} = System.cmd("identify", ["-verbose", path], stderr_to_stdout: true)
    Enum.at(Regex.run(~r/Geometry: ([^+]*)/, identify), 1)
  end

  defp cleanup(path) do
    File.rm(path)
  end
end
