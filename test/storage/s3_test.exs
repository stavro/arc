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

  def env_bucket do
    System.get_env("ARC_TEST_BUCKET")
  end

  setup_all do
    Application.ensure_all_started(:httpoison)
    Application.ensure_all_started(:ex_aws)
    Application.put_env :arc, :virtual_host, false
    Application.put_env :arc, :bucket, env_bucket
    # Application.put_env :ex_aws, :s3, [scheme: "https://", host: "s3.amazonaws.com", region: "us-west-2"]
    Application.put_env :ex_aws, :access_key_id, System.get_env("ARC_TEST_S3_KEY")
    Application.put_env :ex_aws, :secret_access_key,  System.get_env("ARC_TEST_S3_SECRET")
  end

  test "virtual_host" do
    Application.put_env :arc, :virtual_host, false
    url = Arc.Storage.S3.url(DummyDefinition, :original, {Arc.File.new(@img), nil})
    assert "https://s3.amazonaws.com/#{env_bucket}/arctest/uploads/image.png", url

    Application.put_env :arc, :virtual_host, false
    url = Arc.Storage.S3.url(DummyDefinition, :original, {Arc.File.new(@img), nil})
    assert "https://#{env_bucket}.s3.amazonaws.com/arctest/uploads/image.png", url
  end

  @tag :s3
  test "public put and get" do
    #put the image as public
    assert :ok == Arc.Storage.S3.put(DummyDefinition, :original, {Arc.File.new(@img), nil}) |> elem(0)

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
    assert :ok == Arc.Storage.S3.put(DummyDefinition, :private, {Arc.File.new(@img), nil}) |> elem(0)

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
end
