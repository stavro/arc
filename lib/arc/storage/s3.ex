defmodule Arc.Storage.S3 do
  @default_expiry_time 60*5

  def put(definition, version, {file, scope}) do
    destination_dir = definition.storage_dir(version, {file, scope})
    s3_key = Path.join(destination_dir, file.file_name)
    binary = File.read!(file.path)
    acl = definition.acl(version, {file, scope})

    s3_options =
      definition.s3_object_headers(version, {file, scope})
      |> Dict.put(:acl, acl)

    case ExAws.S3.put_object(bucket, s3_key, binary, s3_options) do
      {:ok, _res}     -> {:ok, file.file_name}
      {:error, error} -> {:error, error}
    end
  end

  def url(definition, version, file_and_scope, options \\ []) do
    case Keyword.get(options, :signed, false) do
      false -> build_url(definition, version, file_and_scope, options)
      true  -> build_signed_url(definition, version, file_and_scope, options)
    end
  end

  def delete(definition, version, {file, scope}) do
    ExAws.S3.delete_object bucket, s3_key(definition, version, {file, scope})
  end

  #
  # Private
  #

  defp build_url(definition, version, file_and_scope, _options) do
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
    {:ok, bucket_name} = Application.fetch_env(:arc, :bucket)

    case bucket_name do
      {:system, env_var} when is_binary(env_var) -> System.get_env(env_var)
      name -> name
    end
  end
end
