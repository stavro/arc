defmodule Arc.Storage.S3 do
  @default_expiry_time 60*5

  def put(definition, version, {file, scope}) do
    destination_dir = definition.storage_dir(version, {file, scope})
    s3_key = Path.join(destination_dir, file.file_name)
    binary = File.read!(file.path)
    acl = definition.acl(version, {file, scope})
    ExAws.S3.put_object(bucket, s3_key, binary, [acl: acl])
  end

  def url(definition, version, file_and_scope, options \\ []) do
    case Keyword.get(options, :signed, false) do
      false -> build_url(definition, version, file_and_scope, options)
      true  -> build_signed_url(definition, version, file_and_scope, options)
    end
  end

  def delete(definition, version, {file, scope}) do
    destination_dir = definition.storage_dir(version, {file, scope})
    s3_key = Path.join(destination_dir, file.file_name)
    ExAws.S3.delete_object(bucket, s3_key)
  end

  #
  # Private
  #

  defp build_url(definition, version, file_and_scope, options) do
    Path.join host, s3_key(definition, version, file_and_scope)
  end

  defp build_signed_url(definition, version, file_and_scope, options) do
    expires_in = Keyword.get(options, :expire_in, @default_expiry_time)
    {:ok, url} = ExAws.S3.presigned_url(:get, bucket, s3_key(definition, version, file_and_scope), [expires_in: expires_in, virtual_host: virtual_host])
    url
  end

  defp s3_key(definition, version, file_and_scope) do
    Path.join([
      definition.storage_dir(version, file_and_scope),
      Arc.Definition.Versioning.resolve_file_name(definition, version, file_and_scope)
    ])
  end

  defp host do
    Application.get_env(:arc, :asset_host) || default_host
  end

  defp default_host do
    case virtual_host do
      true -> "https://#{bucket}.s3.amazonaws.com"
      _    -> "https://s3.amazonaws.com/#{bucket}"
    end
  end

  defp virtual_host do
    Application.get_env(:arc, :virtual_host) || false
  end

  defp bucket do
    Application.fetch_env!(:arc, :bucket)
  end
end
