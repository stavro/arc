defmodule ArcTest.Storage.S3HtmlUpload do
  use ExUnit.Case, async: false

  @img "test/support/image.png"

  setup_all do
    Application.ensure_all_started(:hackney)
    Application.ensure_all_started(:httpoison)
    Application.ensure_all_started(:ex_aws)
    Application.put_env :arc, :virtual_host, false
    Application.put_env :arc, :bucket, { :system, "ARC_TEST_BUCKET" }
    Application.put_env :ex_aws, :access_key_id, System.get_env("ARC_TEST_S3_KEY")
    Application.put_env :ex_aws, :secret_access_key,  System.get_env("ARC_TEST_S3_SECRET")
  end

  def upload_image(image, options \\ []) do
    form = Arc.Storage.S3.html_upload_form(options)
    multipart_fields = form.fields |> Map.to_list() |> Kernel.++([{:file, image}])
    {:ok, response} = HTTPoison.post(form.action, {:multipart, multipart_fields})

    if response.status_code === 204 do
      {:ok, form.fields["key"], response}
    else
      {:error, response.body}
    end
  end

  def public_url(key) do
    Arc.Storage.S3.url(key)
  end

  def signed_url(key) do
    Arc.Storage.S3.url(key, signed: true)
  end

  def is_private(key) do
    {:ok, res} =
      key
      |> public_url()
      |> HTTPoison.head()

    res.status_code == 403
  end

  def is_privately_accessible(key) do
    {:ok, res} =
      key
      |> signed_url()
      |> HTTPoison.get()

    res.status_code == 200
  end

  def header_value(key, header) do
    key
    |> public_url()
    |> HTTPoison.head!()
    |> Map.get(:headers)
    |> Enum.find(fn {k, v} -> k == header end)
    |> case do
      {_k, v} -> v
      _ -> nil
    end
  end

  @tag :s3
  test "files are private by default" do
    {:ok, key, response} = upload_image(@img)
    assert is_private(key)
    assert is_privately_accessible(key)
  end

  @tag :s3
  test "files can be made public" do
    {:ok, key, response} = upload_image(@img, acl: "public-read")
    refute is_private(key)
    assert is_privately_accessible(key)
  end

  @tag :s3
  test "files can specify content disposition" do
    disposition = "attachment; filename=\"test.png\""
    {:ok, key, response} = upload_image(@img, acl: "public-read", content_disposition: disposition)
    refute is_private(key)
    assert header_value(key, "Content-Disposition") == disposition
  end

  @tag :s3
  test "uploads can specify content-length range" do
    disposition = "attachment; filename=\"test.png\""
    {:error, error_message} = upload_image(@img, acl: "public-read", content_length_range: [0, 100])
    assert error_message =~ ~r/EntityTooLarge/
  end
end
