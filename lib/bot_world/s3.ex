defmodule BotWorld.S3 do
  @bucket "bot-world"

  def upload_file(file_path, s3_key, content_type) do
    file_path
    |> ExAws.S3.Upload.stream_file()
    |> ExAws.S3.upload(@bucket, s3_key, content_type: content_type)
    |> ExAws.request()
  end
end
