defmodule ArcTest.Storage.Local do
  use ExUnit.Case
  @img "test/support/image.png"

  defmodule DummyDefinition do
    use Arc.Definition.Storage
    @acl :public_read
    def transform(:thumb, _), do: {:convert, "-strip -thumbnail 10x10"}
    def __versions, do: [:original, :thumb]
    def storage_dir(_, _), do: "arctest/uploads"
    def acl(:original, _), do: :public_read
    def acl(:private, _), do: :private
    def __storage, do: Arc.Storage.Local
  end

  test "put, delete, get" do
    assert "image.png" == Arc.Storage.Local.put(DummyDefinition, :original, {Arc.File.new(@img), nil})
    assert true == File.exists?("arctest/uploads/image.png")

    assert "arctest/uploads/image.png" == Arc.Storage.Local.url(DummyDefinition, :original, {Arc.File.new(@img), nil})

    Arc.Storage.Local.delete(DummyDefinition, :original, {Arc.File.new(@img), nil})
    assert false == File.exists?("arctest/uploads/image.png")
  end

end
