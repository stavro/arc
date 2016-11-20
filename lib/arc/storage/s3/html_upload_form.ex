defmodule Arc.Storage.S3.HtmlUploadForm do
  defstruct action: nil, meta: %{}, fields: []

  def generate(options) do
    ex_aws_config = Keyword.fetch!(options, :ex_aws_config)
    form_expires_at = Keyword.get(options, :expires_in, 3600) |> expiration_date() # Defaults to 1 hour

    key = Keyword.fetch!(options, :key)
    acl = Keyword.fetch!(options, :acl)
    bucket = Keyword.fetch!(options, :bucket)

    timestamp = :calendar.universal_time()

    html_upload_form = %__MODULE__{
      action: "https://#{bucket}.s3.amazonaws.com/",
      meta: %{
        expires_at: form_expires_at,
        bucket: bucket
      },
      fields: %{
        "key" => key,
        "acl" => acl,
        "x-amz-credential" => amz_credential(ex_aws_config.access_key_id, timestamp, ex_aws_config.region),
        "x-amz-algorithm" => "AWS4-HMAC-SHA256",
        "x-amz-date" => amz_datetime(timestamp),
      }
    }

    html_upload_form =
      html_upload_form
      |> apply_content_headers(options)
      |> apply_redirect_headers(options)

    policy = generate_encoded_policy(html_upload_form, options)
    signature = sign_policy(ex_aws_config, policy, timestamp)

    html_upload_form
    |> add_form_field_exact("policy", policy)
    |> add_form_field_exact("x-amz-signature", signature)
  end

  defp add_form_field_exact(form, key, value) do
    %__MODULE__{form | fields: Map.put(form.fields, key, value)}
  end

  defp apply_content_headers(form, options) do
    [:content_disposition, :content_type] |> Enum.reduce(form, fn(key, form) ->
      if value = Keyword.get(options, key) do
        add_form_field_exact(form, dasherize(key), value)
      else
        form
      end
    end)
  end

  defp apply_redirect_headers(form, options) do
    [:success_action_redirect] |> Enum.reduce(form, fn(key, form) ->
      if value = Keyword.get(options, key) do
        add_form_field_exact(form, key, value)
      else
        form
      end
    end)
  end

  defp dasherize(key) do
    key |> to_string() |> String.replace("_", "-")
  end

  defp generate_encoded_policy(form, options) do
    policy_conditions =
      [%{"bucket" => form.meta.bucket} | to_list_of_maps(form.fields)]
      |> append_content_length_range_policy(options)

    policy_document = %{
      expiration: iso_z(form.meta.expires_at),
      conditions: policy_conditions
    }

    policy_document
    |> Poison.encode!()
    |> Base.encode64()
  end

  defp append_content_length_range_policy(conditions, options) do
    if range = Keyword.get(options, :content_length_range) do
      conditions ++ [["content-length-range" | range]]
    else
      conditions
    end
  end

  defp to_list_of_maps(map) do
    map
    |> Map.to_list()
    |> Enum.map(fn {k,v} -> %{k => v} end)
  end

  def sign_policy(config, encoded_policy, timestamp) do
    ExAws.Auth.Signatures.generate_signature_v4("s3", config, timestamp, encoded_policy)
  end

  defp amz_credential(access_key_id, timestamp, region) do
    [
      access_key_id,
      amz_date(timestamp),
      region,
      "s3",
      "aws4_request"
    ] |> Enum.join("/")
  end

  defp amz_date({{year, month, day}, _}) do
    Enum.join([
      year,
      zero_pad(month),
      zero_pad(day)
    ])
  end

  defp iso_z({{year, month, day}, {hour, min, secs}}) do
    Enum.join([
      year,
      "-",
      zero_pad(month),
      "-",
      zero_pad(day),
      "T",
      zero_pad(hour),
      ":",
      zero_pad(min),
      ":",
      zero_pad(secs),
      "Z"
    ])
  end

  defp amz_datetime({{year, month, day}, {hour, min, secs}}) do
    Enum.join([
      year,
      zero_pad(month),
      zero_pad(day),
      "T",
      zero_pad(hour),
      zero_pad(min),
      zero_pad(secs),
      "Z"
    ])
  end

  defp expiration_date(seconds_ahead) do
    :calendar.universal_time()
    |> :calendar.datetime_to_gregorian_seconds()
    |> Kernel.+(seconds_ahead)
    |> :calendar.gregorian_seconds_to_datetime()
  end

  defp zero_pad(<<_>> = val) when is_binary(val), do: "0" <> val
  defp zero_pad(val) when is_binary(val), do: val
  defp zero_pad(non_binary), do: zero_pad(to_string(non_binary))
end
