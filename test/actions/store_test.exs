defmodule ArcTest.Actions.Store do
  use ExUnit.Case, async: false
  @img "test/support/image.png"
  import Mock

  defmodule DummyDefinition do
    use Arc.Actions.Store
    use Arc.Definition.Storage

    def validate({file, _}) do
      if String.ends_with?(file.file_name, ".png") do
        {:ok, :ok}
      else
        {:error, :invalid_file}
      end
    end

    def transform(_, _), do: :noaction
    def __versions, do: [:original, :thumb]
  end

  test "checks file existance" do
    assert DummyDefinition.store("non-existant-file.png") == {:error, :invalid_file}
  end

  test "delegates to definition validation" do
    assert DummyDefinition.store(__ENV__.file) == {:error, :invalid_file}
  end

  test "single binary argument is interpreted as file path" do
    with_mock Arc.Storage.S3, [put: fn(DummyDefinition, _, {%{file_name: "image.png", path: @img}, nil}) -> {:ok, "resp"} end] do
      assert DummyDefinition.store(@img) == {:ok, "image.png"}
    end
  end

  test "two-tuple argument interpreted as path and scope" do
    with_mock Arc.Storage.S3, [put: fn(DummyDefinition, _, {%{file_name: "image.png", path: @img}, :scope}) -> {:ok, "resp"} end] do
      assert DummyDefinition.store({@img, :scope}) == {:ok, "image.png"}
    end
  end

  test "map with a filename and path" do
    with_mock Arc.Storage.S3, [put: fn(DummyDefinition, _, {%{file_name: "image.png", path: @img}, nil}) -> {:ok, "resp"} end] do
      assert DummyDefinition.store(%{filename: "image.png", path: @img}) == {:ok, "image.png"}
    end
  end

  test "two-tuple with Plug.Upload and a scope" do
    with_mock Arc.Storage.S3, [put: fn(DummyDefinition, _, {%{file_name: "image.png", path: @img}, :scope}) -> {:ok, "resp"} end] do
      assert DummyDefinition.store({%{filename: "image.png", path: @img}, :scope}) == {:ok, "image.png"}
    end
  end

  test "error from ExAws on upload to S3" do
    with_mock Arc.Storage.S3, [put: fn(DummyDefinition, _, {%{file_name: "image.png", path: @img}, :scope}) -> {:error, {:http_error, 404, "XML"}} end] do
      assert DummyDefinition.store({%{filename: "image.png", path: @img}, :scope}) == {:error, [{:http_error, 404, "XML"}, {:http_error, 404, "XML"}]}
    end
  end

  test "timeout" do
    Application.put_env :arc, :version_timeout, 1

    catch_exit do
      with_mock Arc.Storage.S3, [put: fn(DummyDefinition, _, {%{file_name: "image.png", path: @img}, :scope}) -> :timer.sleep(100) && :ok end] do
        assert DummyDefinition.store({%{filename: "image.png", path: @img}, :scope}) == {:ok, "image.png"}
      end
    end

    Application.put_env :arc, :version_timeout, 15_000
  end
end
