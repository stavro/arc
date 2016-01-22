defmodule ArcTest.Storage.S3 do
  use ExUnit.Case, async: false
  @img "test/support/image.png"

  defmodule DummyDefinition do
    use Arc.Definition

    @acl :public_read
    def storage_dir(_, _), do: "arctest/uploads"
    def acl(_, {_, :private}), do: :private

    def s3_object_headers(:original, {_, :with_content_type}), do: [content_type: "image/gif"]
    def s3_object_headers(:original, {_, :with_content_disposition}), do: %{content_disposition: "attachment; filename=abc.png"}
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
    Application.put_env :arc, :virtual_host, true
    assert "https://#{env_bucket}.s3.amazonaws.com/arctest/uploads/image.png" == DummyDefinition.url(@img)

    Application.put_env :arc, :virtual_host, false
    assert "https://s3.amazonaws.com/#{env_bucket}/arctest/uploads/image.png" == DummyDefinition.url(@img)
  end

  @tag :s3
  @tag timeout: 15000
  test "public put and get" do
    #put the image as public
    assert {:ok, "image.png"} == DummyDefinition.store(@img)

    #verify image is accessible
    {:ok, {{_, 200, 'OK'}, _, _}} = :httpc.request(to_char_list(DummyDefinition.url(@img)))

    #delete the image
    Arc.Storage.S3.delete(DummyDefinition, :original, {Arc.File.new(@img), nil})

    #verify image is not found
    signed_url = Arc.Storage.S3.url(DummyDefinition, :original, {Arc.File.new(@img), nil}, [signed: true])
    {:ok, {{_, 404, 'Not Found'}, _, _}} = :httpc.request(to_char_list(signed_url))
  end

  @tag :s3
  @tag timeout: 15000
  test "private put and signed get" do
    #put the image as private
    assert {:ok, "image.png"} == DummyDefinition.store({@img, :private})

    unsigned_url = DummyDefinition.url(@img)

    #verify image is not accessible
    {:ok, {{_, 403, 'Forbidden'}, _, _}} = :httpc.request(to_char_list(unsigned_url))

    #get a signed_url to the image
    signed_url = DummyDefinition.url(@img, signed: true)

    #verify image is accessible
    {:ok, {{_, 200, 'OK'}, _, _}} = :httpc.request(to_char_list(signed_url))

    #delete the image
    Arc.Storage.S3.delete(DummyDefinition, :private, {Arc.File.new(@img), nil})

    #verify image is not found
    {:ok, {{_, 404, 'Not Found'}, _, _}} = :httpc.request(to_char_list(signed_url))
  end


  @tag :s3
  @tag timeout: 15000
  test "content_type" do
    assert {:ok, "image.png"} == DummyDefinition.store({@img, :with_content_type})

    url = DummyDefinition.url(@img)

    {:ok, {{_, 200, 'OK'}, headers, _}} = :httpc.request(to_char_list(url))

    assert 'image/gif' == Enum.find_value(headers, fn(
      {'content-type', value}) -> value
      _ -> nil
    end)

    Arc.Storage.S3.delete(DummyDefinition, :original, {Arc.File.new(@img), :with_content_type})
  end

  @tag :s3
  @tag timeout: 15000
  test "content_disposition" do
    #put the image as private
    assert {:ok, "image.png"} == DummyDefinition.store({@img, :with_content_disposition})

    url = DummyDefinition.url(@img)

    #verify image is not accessible
    {:ok, {{_, 200, 'OK'}, headers, _}} = :httpc.request(to_char_list(url))

    assert 'attachment; filename=abc.png' == Enum.find_value(headers, fn(
      {'content-disposition', value}) -> value
      _ -> nil
    end)

    Arc.Storage.S3.delete(DummyDefinition, :original, {Arc.File.new(@img), nil})
  end
end
