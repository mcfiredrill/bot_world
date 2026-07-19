defmodule BotWorld.S3 do
  @bucket "bot-world"
  @region "us-east-1"

  def bucket, do: @bucket

  def upload_file(file_path, s3_key, content_type, request_fun \\ &ExAws.request/1) do
    upload = build_upload(file_path, s3_key, content_type)

    case request_fun.(upload) do
      {:ok, _result} = ok ->
        ok

      {:error, reason} ->
        if bucket_missing?(reason) do
          with :ok <- ensure_bucket_exists(request_fun) do
            request_fun.(upload)
          end
        else
          {:error, reason}
        end
    end
  end

  def presign_upload(s3_key, content_type, opts \\ []) do
    expires_in = Keyword.get(opts, :expires_in, 3600)
    headers = [{"content-type", content_type}]

    :s3
    |> ExAws.Config.new()
    |> ExAws.S3.presigned_url(:put, @bucket, s3_key, expires_in: expires_in, headers: headers)
    |> case do
      {:ok, url} ->
        {:ok,
         %{
           key: s3_key,
           method: "PUT",
           url: url,
           headers: %{"content-type" => content_type},
           expires_in: expires_in
         }}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def public_url(key) do
    %URI{
      scheme: endpoint_scheme(),
      host: endpoint_host(),
      port: endpoint_port(),
      path: "/#{@bucket}/#{key}"
    }
    |> URI.to_string()
  end

  defp build_upload(file_path, s3_key, content_type) do
    file_path
    |> ExAws.S3.Upload.stream_file()
    |> ExAws.S3.upload(@bucket, s3_key, content_type: content_type)
  end

  defp ensure_bucket_exists(request_fun) do
    case request_fun.(ExAws.S3.put_bucket(@bucket, @region)) do
      {:ok, _result} ->
        :ok

      {:error, reason} ->
        if bucket_already_exists?(reason) do
          :ok
        else
          {:error, reason}
        end
    end
  end

  defp bucket_missing?(reason) do
    error_matches?(reason, ["nosuchbucket", "specified bucket does not exist"])
  end

  defp bucket_already_exists?(reason) do
    error_matches?(reason, ["bucketalreadyexists", "bucketalreadyownedbyyou"])
  end

  defp error_matches?(reason, phrases) when is_binary(reason) do
    normalized_reason = String.downcase(reason)
    Enum.any?(phrases, &String.contains?(normalized_reason, &1))
  end

  defp error_matches?(reason, phrases) when is_list(reason) do
    Enum.any?(reason, &error_matches?(&1, phrases))
  end

  defp error_matches?(reason, phrases) when is_tuple(reason) do
    reason
    |> Tuple.to_list()
    |> error_matches?(phrases)
  end

  defp error_matches?(reason, phrases) when is_map(reason) do
    reason
    |> Map.values()
    |> error_matches?(phrases)
  end

  defp error_matches?(_reason, _phrases), do: false

  defp endpoint_scheme do
    :ex_aws
    |> Application.get_env(:s3, [])
    |> Keyword.get(:scheme, "https://")
    |> String.trim_trailing("://")
  end

  defp endpoint_host do
    :ex_aws
    |> Application.get_env(:s3, [])
    |> Keyword.get(:host, "s3.amazonaws.com")
  end

  defp endpoint_port do
    :ex_aws
    |> Application.get_env(:s3, [])
    |> Keyword.get(:port)
  end
end
