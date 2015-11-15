defmodule ArcTest.Storage.S3 do
  use ExUnit.Case
  @img "test/support/image.png"

  defmodule DummyDefinition do
    use Arc.Definition.Storage
    @acl :public_read
    def transform(_, _), do: {:noaction}
    def storage_dir(_, _), do: "arctest/uploads"
    def acl(:original, _), do: :public_read
    def acl(:private, _), do: :private
  end

  setup_all do
    :erlcloud.start
    Application.put_env :arc, :bucket, System.get_env("ARC_TEST_BUCKET")
    Application.put_env :arc, :access_key_id, System.get_env("ARC_TEST_S3_KEY")
    Application.put_env :arc, :secret_access_key,  System.get_env("ARC_TEST_S3_SECRET")
  end

  @tag :s3
  test "public put and get" do
    #put the image as public
    assert "image.png" == Arc.Storage.S3.put(DummyDefinition, :original, {Arc.File.new(@img), nil})

    #get a url to the image
    url = Arc.Storage.S3.url(DummyDefinition, :original, {Arc.File.new(@img), nil})

    #verify image is accessible
    {:ok, {{_, 200, 'OK'}, _, _}} = :httpc.request(to_char_list(url))

    #delete the image
    Arc.Storage.S3.delete(DummyDefinition, :original, {Arc.File.new(@img), nil})

    #verify image is not found
    signed_url = Arc.Storage.S3.url(DummyDefinition, :original, {Arc.File.new(@img), nil}, [signed: true])
    {:ok, {{_, 404, 'Not Found'}, _, _}} = :httpc.request(to_char_list(signed_url))
  end

  @tag :s3
  test "private put and signed get" do
    #put the image as private
    assert "image.png" == Arc.Storage.S3.put(DummyDefinition, :private, {Arc.File.new(@img), nil})

    #get a url to the image
    url = Arc.Storage.S3.url(DummyDefinition, :private, {Arc.File.new(@img), nil})

    #verify image is not accessible
    {:ok, {{_, 403, 'Forbidden'}, _, _}} = :httpc.request(to_char_list(url))

    #get a signed_url to the image
    signed_url = Arc.Storage.S3.url(DummyDefinition, :private, {Arc.File.new(@img), nil}, [signed: true])

    #verify image is accessible
    {:ok, {{_, 200, 'OK'}, _, _}} = :httpc.request(to_char_list(signed_url))

    #delete the image
    Arc.Storage.S3.delete(DummyDefinition, :private, {Arc.File.new(@img), nil})

    #verify image is not found
    {:ok, {{_, 404, 'Not Found'}, _, _}} = :httpc.request(to_char_list(signed_url))
  end

  test "issues error message when missing env vars" do
    Application.put_env :arc, :access_key_id, "XXXXXXX"
    Application.put_env :arc, :secret_access_key, nil
    assert_raise Arc.Error.InvalidCredentialsError, fn ->
      Arc.Storage.S3.put(DummyDefinition, :private, {Arc.File.new(@img), nil})
    end

    Application.put_env :arc, :access_key_id, nil
    Application.put_env :arc, :secret_access_key, "XXXXXXX"
    assert_raise Arc.Error.InvalidCredentialsError, fn ->
      Arc.Storage.S3.put(DummyDefinition, :private, {Arc.File.new(@img), nil})
    end
  end
end
