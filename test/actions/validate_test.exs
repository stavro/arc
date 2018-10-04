defmodule ArcTest.Actions.Validate do
  use ExUnit.Case, async: false
  @img "test/support/image.png"

  defmodule DummyDefinition do
    use Arc.Actions.Validate
    def validate({file, _}), do: String.ends_with?(file.file_name, ".png") || String.ends_with?(file.file_name, ".ico")
  end

  test "checks file existance" do
    assert DummyDefinition.valid?("non-existant-file.png") == {:error, :invalid_file_path}
  end

  test "checks file type" do
    assert DummyDefinition.valid?(__ENV__.file) == {:error, :invalid_file}
  end

  test "checks file is valid" do
    assert DummyDefinition.valid?(@img) == {:ok}
  end

end
