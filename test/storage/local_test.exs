defmodule ArcTest.Storage.Local do
  use ExUnit.Case
  @img "test/support/image.png"

  setup_all do
    File.mkdir_p("arctest/uploads")
  end


  defmodule DummyDefinition do
    use Arc.Definition.Storage
    @acl :public_read
    def transform(:thumb, _), do: {:convert, "-strip -thumbnail 10x10"}
    def __versions, do: [:original, :thumb]
    def storage_dir(_, _), do: "arctest/uploads"
    def __storage, do: Arc.Storage.Local
    def filename(version,  file), do: "#{version}-#{file.file_name}"
  end

  test "put, delete, get" do
    assert "original-image.png" == Arc.Storage.Local.put(DummyDefinition, :original, {Arc.File.new(@img), nil})
    assert "thumb-image.png" == Arc.Storage.Local.put(DummyDefinition, :thumb, {Arc.File.new(@img), nil})
    assert true == File.exists?("arctest/uploads/original-image.png")
    assert true == File.exists?("arctest/uploads/thumb-image.png")

    assert "arctest/uploads/original-image.png" == Arc.Storage.Local.url(DummyDefinition, :original, {Arc.File.new(@img), nil})
    assert "arctest/uploads/thumb-image.png" == Arc.Storage.Local.url(DummyDefinition, :thumb, {Arc.File.new(@img), nil})

    Arc.Storage.Local.delete(DummyDefinition, :original, {Arc.File.new(@img), nil})
    Arc.Storage.Local.delete(DummyDefinition, :thumb, {Arc.File.new(@img), nil})
    assert false == File.exists?("arctest/uploads/original-image.png")
  end

end
