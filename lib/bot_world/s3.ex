defmodule BotWorld.S3 do
  @bucket "bot-world"
  @region "us-east-1"

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
end
