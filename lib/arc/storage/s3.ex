defmodule Arc.Storage.S3 do
  @default_expiry_time 60*5

  def put(definition, version, {file, scope}) do
    destination_dir = definition.storage_dir(version, {file, scope})
    s3_key = Path.join(destination_dir, file.file_name) |> String.to_char_list
    {:ok, binary} = File.read(file.path)
    acl = definition.acl(version, {file, scope})
    :erlcloud_s3.put_object(bucket, s3_key, binary, [acl: acl], erlcloud_config)
    file.file_name
  end

  def url(definition, version, file_and_scope, options \\ []) do
    case Keyword.get(options, :signed, false) do
      false -> build_url(definition, version, file_and_scope, options)
      true  -> build_signed_url(definition, version, file_and_scope, options)
    end
  end

  def delete(definition, version, {file, scope}) do
    destination_dir = definition.storage_dir(version, {file, scope})
    s3_key = Path.join(destination_dir, file.file_name) |> String.to_char_list
    :erlcloud_s3.delete_object(bucket, s3_key, erlcloud_config)
  end

  #
  # Private
  #

  defp build_url(definition, version, file_and_scope, options) do
    Path.join host, s3_key(definition, version, file_and_scope)
  end

  defp build_signed_url(definition, version, file_and_scope, options) do
    expire_in = Keyword.get(options, :expire_in, @default_expiry_time)
    make_get_url(expire_in, bucket_name, s3_key(definition, version, file_and_scope), erlcloud_config)
    |> Path.join("")
  end

  defp s3_key(definition, version, file_and_scope) do
    Path.join([
      definition.storage_dir(version, file_and_scope),
      Arc.Definition.Versioning.resolve_file_name(definition, version, file_and_scope)
    ])
  end

  defp host do
    Application.get_env(:arc, :asset_host) || "https://s3.amazonaws.com/#{bucket_name}"
  end

  defp bucket_name do
    Application.get_env(:arc, :bucket)
  end

  defp erlcloud_config do
    :erlcloud_s3.new(
      to_char_list(Application.get_env(:arc, :access_key_id)),
      to_char_list(Application.get_env(:arc, :secret_access_key)),
      's3.amazonaws.com'
    )
  end

  defp bucket do
    {:ok, bucket} = Application.fetch_env(:arc, :bucket)
    to_char_list(bucket)
  end

  defp make_get_url(expire, bucket_name, s3_key, config) do
    :erlcloud_s3.make_get_url(expire,
      to_char_list(bucket_name),
      to_char_list(s3_key),
      config
    )
  end
end
