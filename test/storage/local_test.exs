defmodule ArcTest.Storage.Local do
  use ExUnit.Case
  @img "test/support/image.png"

  setup_all do
    File.mkdir_p("arctest/uploads")

    on_exit fn ->
      File.rm_rf("arctest/uploads")
    end
  end


  defmodule DummyDefinition do
    use Arc.Definition.Storage
    use Arc.Actions.Url
    use Arc.Definition.Storage

    @acl :public_read
    def transform(:thumb, _), do: {:convert, "-strip -thumbnail 10x10"}
    def transform(:original, _), do: :noaction
    def __versions, do: [:original, :thumb]
    def storage_dir(_, _), do: "arctest/uploads"
    def __storage, do: Arc.Storage.Local
    def filename(:original, {file, _}), do: "original-#{Path.basename(file.file_name, Path.extname(file.file_name))}"
    def filename(:thumb, {file, _}), do: "1/thumb-#{Path.basename(file.file_name, Path.extname(file.file_name))}"
  end

  test "put, delete, get" do
    assert {:ok, "original-image.png"} == Arc.Storage.Local.put(DummyDefinition, :original, {Arc.File.new(%{filename: "original-image.png", path: @img}), nil})
    assert {:ok, "1/thumb-image.png"} == Arc.Storage.Local.put(DummyDefinition, :thumb, {Arc.File.new(%{filename: "1/thumb-image.png", path: @img}), nil})

    assert File.exists?("arctest/uploads/original-image.png")
    assert File.exists?("arctest/uploads/1/thumb-image.png")
    assert "/arctest/uploads/original-image.png" == DummyDefinition.url("image.png", :original)
    assert "/arctest/uploads/1/thumb-image.png" == DummyDefinition.url("1/image.png", :thumb)

    :ok = Arc.Storage.Local.delete(DummyDefinition, :original, {%{file_name: "image.png"}, nil})
    :ok = Arc.Storage.Local.delete(DummyDefinition, :thumb, {%{file_name: "image.png"}, nil})
    refute File.exists?("arctest/uploads/original-image.png")
    refute File.exists?("arctest/uploads/1/thumb-image.png")
  end

  test "save binary" do
    Arc.Storage.Local.put(DummyDefinition, :original, {Arc.File.new(%{binary: "binary", filename: "binary.png"}), nil})
    assert true == File.exists?("arctest/uploads/binary.png")
  end

  test "encoded url" do
    url = Arc.Storage.Local.url(DummyDefinition, :original, {Arc.File.new(%{binary: "binary", filename: "binary file.png"}), nil})
    assert "/arctest/uploads/original-binary%20file.png" == url
  end
end
