defmodule Arc.Storage.S3 do
  require Logger
  @default_expiry_time 60*5

  def put(definition, version, {file, scope}) do
    destination_dir = definition.storage_dir(version, {file, scope})
    s3_key = Path.join(destination_dir, file.file_name)
    acl = definition.acl(version, {file, scope})

    s3_options =
      definition.s3_object_headers(version, {file, scope})
      |> ensure_keyword_list()
      |> Dict.put(:acl, acl)

    do_put(file, s3_key, s3_options)
  end

  def url(definition, version, file_and_scope, options \\ []) do
    compose_s3_key(definition, version, file_and_scope)
    |> url(options)
  end

  def url(s3_key, options \\ []) when is_binary(s3_key) do
    case Keyword.get(options, :signed, false) do
      false -> build_url(s3_key, options)
      true  -> build_signed_url(s3_key, options)
    end
  end

  def delete(definition, version, {file, scope}) do
    compose_s3_key(definition, version, {file, scope})
    |> delete()
  end

  def delete(s3_key) when is_binary(s3_key) do
    bucket()
    |> ExAws.S3.delete_object(s3_key)
    |> ExAws.request()

    :ok
  end

  @doc """
  Generates an upload form capable of submitting a file directly to Amazon S3.

  ## Options

    * `:bucket` - Which bucket the upload will be placed in. Defaults to the
      Arc bucket.
    * `:key` - The S3 key (or file path) where the upload will be stored,
      defaults to `uploads/#{Arc.UUID.generate()}`
    * `:acl` - The access control policy to apply to the uploaded file. If you
      do not want the uploaded file to be made available to the general public,
      you should use the value `private`.  To make the uploaded file publicly
      available, use the value `public-read`. Defaults to `private`.
    * `:expires_in` - A value in seconds that specifies how long the policy
      document will be valid for. Once a policy document has expired, the
      upload form will no longer work.
    * `:content_length_range` - Content length range as `[min, max]`, where
       S3 will check that the size of an uploaded file is between a given
       minimum and maximum value (in bytes). If this rule is not included in a
       policy document, users will be able to upload files of any size up to
       the 5GB limit imposed by S3.
    * `:content_disposition` - Content header passed through to Amazon S3.  This
      allows you to specify that the file is an attachment, and what filename
      the upload should be downloaded as.  Eg. `attachment; filename=image.png`
    * `:content_type`- The content type (mime type) that will be applied to the
      uploaded file, for example image/jpeg for JPEG picture files. If you do
      not know what type of file a user will upload, you can either let the
      user choose the file prior to generating this upload form to determine
      the appropriate content type.  If you do not set the content type with
      this field, S3 will use the default value application/octet-stream which
      may prevent some web browsers from being able to display the file
      properly.
    * `:success_action_redirect` - The URL address to which the user’s web
      browser will be redirected after the file is uploaded. This URL should
      point to a “Successful Upload” page on your web site, so you can inform
      your users that their files have been accepted. S3 will add bucket,
      key and etag parameters to this URL value to inform your web application
      of the location and hash value of the uploaded file.
  """
  def html_upload_form(options \\ []) do
    ex_aws_config = ExAws.Config.new(:s3, Application.get_all_env(:ex_aws))

    options = Keyword.merge([
      ex_aws_config: ex_aws_config,
      key: "uploads/#{Arc.UUID.generate()}",
      acl: "private",
      expires_in: 3600,
      bucket: bucket()
    ], options)

    Arc.Storage.S3.HtmlUploadForm.generate(options)
  end

  #
  # Private
  #

  defp ensure_keyword_list(list) when is_list(list), do: list
  defp ensure_keyword_list(map) when is_map(map), do: Map.to_list(map)

  # If the file is stored as a binary in-memory, send to AWS in a single request
  defp do_put(file=%Arc.File{binary: file_binary}, s3_key, s3_options) when is_binary(file_binary) do
    ExAws.S3.put_object(bucket(), s3_key, file_binary, s3_options)
    |> ExAws.request()
    |> case do
      {:ok, _res}     -> {:ok, file.file_name}
      {:error, error} -> {:error, error}
    end
  end

  # Stream the file and upload to AWS as a multi-part upload
  defp do_put(file, s3_key, s3_options) do

    try do
      file.path
      |> ExAws.S3.Upload.stream_file()
      |> ExAws.S3.upload(bucket(), s3_key, s3_options)
      |> ExAws.request()
      |> case do
        # :done -> {:ok, file.file_name}
        {:ok, :done} -> {:ok, file.file_name}
        {:error, error} -> {:error, error}
      end
    rescue
      e in ExAws.Error ->
        Logger.error(inspect e)
        Logger.error(e.message)
        {:error, :invalid_bucket}
    end
  end


  defp build_url(s3_key, options \\ []) when is_binary(s3_key) do
    Path.join(host, s3_key)
  end

  defp build_signed_url(s3_key, options \\ []) do
    defaults = [expire_in: @default_expiry_time, virtual_host: virtual_host()]
    ex_aws_options = Keyword.merge(defaults, options)
    config = ExAws.Config.new(:s3, Application.get_all_env(:ex_aws))
    {:ok, url} = ExAws.S3.presigned_url(config, :get, bucket, s3_key, ex_aws_options)
    url
  end

  defp compose_s3_key(definition, version, file_and_scope) do
    Path.join([
      definition.storage_dir(version, file_and_scope),
      Arc.Definition.Versioning.resolve_file_name(definition, version, file_and_scope)
    ])
  end

  defp host do
    host_url = Application.get_env(:arc, :asset_host, default_host)

    case host_url do
      {:system, env_var} when is_binary(env_var) -> System.get_env(env_var)
      url -> url
    end
  end

  defp default_host do
    case virtual_host() do
      true -> "https://#{bucket}.s3.amazonaws.com"
      _    -> "https://s3.amazonaws.com/#{bucket}"
    end
  end

  defp virtual_host do
    Application.get_env(:arc, :virtual_host) || false
  end

  defp bucket do
    {:ok, bucket_name} = Application.fetch_env(:arc, :bucket)

    case bucket_name do
      {:system, env_var} when is_binary(env_var) -> System.get_env(env_var)
      name -> name
    end
  end
end
