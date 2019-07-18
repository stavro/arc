defmodule ArcTest.Storage.Local do
  use ExUnit.Case
  @img "test/support/image.png"
  @badimg "test/support/invalid_image.png"

  setup_all do
    File.mkdir_p("arctest/uploads")

    on_exit fn ->
      File.rm_rf("arctest/uploads")
    end
  end


  defmodule DummyDefinition do
    use Arc.Definition

    @acl :public_read
    def transform(:thumb, _), do: {:convert, "-strip -thumbnail 10x10"}
    def transform(:original, _), do: :noaction
    def transform(:skipped, _), do: :skip
    def __versions, do: [:original, :thumb, :skipped]
    def storage_dir(_, _), do: "arctest/uploads"
    def __storage, do: Arc.Storage.Local
    def filename(:original, {file, _}), do: "original-#{Path.basename(file.file_name, Path.extname(file.file_name))}"
    def filename(:thumb, {file, _}), do: "1/thumb-#{Path.basename(file.file_name, Path.extname(file.file_name))}"
    def filename(:skipped, {file, _}), do: "1/skipped-#{Path.basename(file.file_name, Path.extname(file.file_name))}"
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

  test "deleting when there's a skipped version" do
    DummyDefinition.store(@img)
    assert :ok = DummyDefinition.delete(@img)
  end

  test "save binary" do
    Arc.Storage.Local.put(DummyDefinition, :original, {Arc.File.new(%{binary: "binary", filename: "binary.png"}), nil})
    assert true == File.exists?("arctest/uploads/binary.png")
  end

  test "encoded url" do
    url = DummyDefinition.url(Arc.File.new(%{binary: "binary", filename: "binary file.png"}), :original)
    assert "/arctest/uploads/original-binary%20file.png" == url
  end

  test "url for skipped version" do
    url = DummyDefinition.url(Arc.File.new(%{binary: "binary", filename: "binary file.png"}), :skipped)
    assert url == nil
  end

  test "if one transform fails, they all fail" do
    filepath = @badimg
    [filename] = String.split(@img, "/") |> Enum.reverse |> Enum.take(1)
    assert File.exists?(filepath)
    DummyDefinition.store(filepath)

    assert !File.exists?("arctest/uploads/original-#{filename}")
    assert !File.exists?("arctest/uploads/1/thumb-#{filename}")
  end
end
