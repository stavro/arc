defmodule ArcTest.Storage.Filesystem do
  use ExUnit.Case
  @img "test/support/image.png"

  setup_all do
    File.mkdir_p("arctest/filesystem_uploads")

    on_exit fn ->
      File.rm_rf("arctest/filesystem_uploads")
    end
  end


  defmodule DummyDefinition do
    use Arc.Definition.Storage
    use Arc.Actions.Url

    @acl :public_read
    def transform(:thumb, _), do: {:convert, "-strip -thumbnail 10x10"}
    def transform(:original, _), do: :noaction
    def __versions, do: [:original, :thumb]
    def storage_dir(_, _), do: "img"
    def __storage, do: Arc.Storage.Filesystem
    def filename(:original, {file, _}), do: "original-#{Path.basename(file.file_name, Path.extname(file.file_name))}"
    def filename(:thumb, {file, _}), do: "1/thumb-#{Path.basename(file.file_name, Path.extname(file.file_name))}"
  end

  test "put, delete, get with static upload_dir" do
    Application.put_env(:arc, :upload_dir, "arctest/filesystem_uploads")
    test_put_delete_get()
  end

  test "put, delete, get with :system upload_dir" do
    System.put_env("PATH", "arctest/filesystem_uploads")
    Application.put_env(:arc, :upload_dir, {:system, "PATH"})
    test_put_delete_get()
  end

  defp test_put_delete_get() do
    assert {:ok, "original-image.png"} == Arc.Storage.Filesystem.put(DummyDefinition, :original, {Arc.File.new(%{filename: "original-image.png", path: @img}), nil})
    assert {:ok, "1/thumb-image.png"} == Arc.Storage.Filesystem.put(DummyDefinition, :thumb, {Arc.File.new(%{filename: "1/thumb-image.png", path: @img}), nil})

    assert File.exists?("arctest/filesystem_uploads/img/original-image.png")
    assert File.exists?("arctest/filesystem_uploads/img/1/thumb-image.png")
    assert "/img/original-image.png" == DummyDefinition.url("image.png", :original)
    assert "/img/1/thumb-image.png" == DummyDefinition.url("1/image.png", :thumb)

    :ok = Arc.Storage.Filesystem.delete(DummyDefinition, :original, {%{file_name: "image.png"}, nil})
    :ok = Arc.Storage.Filesystem.delete(DummyDefinition, :thumb, {%{file_name: "image.png"}, nil})
    refute File.exists?("arctest/filesystem_uploads/img/original-image.png")
    refute File.exists?("arctest/filesystem_uploads/img/1/thumb-image.png")
  end  

  test "save binary" do
    Arc.Storage.Filesystem.put(DummyDefinition, :original, {Arc.File.new(%{binary: "binary", filename: "binary.png"}), nil})
    assert true == File.exists?("arctest/filesystem_uploads/img/binary.png")
  end
end
