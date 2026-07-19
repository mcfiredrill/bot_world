defmodule BotWorld.S3Test do
  use ExUnit.Case, async: true

  alias BotWorld.S3

  test "creates the bucket and retries when upload fails because the bucket is missing" do
    parent = self()
    counter = :counters.new(1, [])
    file_path = temp_file_path()

    File.write!(file_path, "test")
    on_exit(fn -> File.rm(file_path) end)

    request_fun = fn
      %ExAws.S3.Upload{} = upload ->
        :counters.add(counter, 1, 1)
        attempt = :counters.get(counter, 1)
        send(parent, {:upload_attempt, attempt, upload.bucket, upload.path})

        if attempt == 1 do
          {:error, "The specified bucket does not exist"}
        else
          {:ok, %{body: %{key: upload.path}}}
        end

      %ExAws.Operation.S3{http_method: :put, bucket: bucket, path: "/"} ->
        send(parent, {:put_bucket, bucket})
        {:ok, %{}}
    end

    assert {:ok, %{body: %{key: "sfx/test.mp3"}}} =
             S3.upload_file(file_path, "sfx/test.mp3", "audio/mpeg", request_fun)

    assert_received {:upload_attempt, 1, "bot-world", "sfx/test.mp3"}
    assert_received {:put_bucket, "bot-world"}
    assert_received {:upload_attempt, 2, "bot-world", "sfx/test.mp3"}
  end

  test "returns non-bucket upload errors without trying to create the bucket" do
    parent = self()
    file_path = temp_file_path()

    File.write!(file_path, "test")
    on_exit(fn -> File.rm(file_path) end)

    request_fun = fn
      %ExAws.S3.Upload{} = upload ->
        send(parent, {:upload_attempt, upload.bucket, upload.path})
        {:error, :econnrefused}

      %ExAws.Operation.S3{} ->
        send(parent, :unexpected_bucket_creation)
        {:ok, %{}}
    end

    assert {:error, :econnrefused} =
             S3.upload_file(file_path, "sfx/test.mp3", "audio/mpeg", request_fun)

    assert_received {:upload_attempt, "bot-world", "sfx/test.mp3"}
    refute_received :unexpected_bucket_creation
  end

  test "creates a public URL from the configured S3 endpoint" do
    assert S3.public_url("video/celebration.mp4") ==
             "http://localhost:9000/bot-world/video/celebration.mp4"
  end

  test "presigns direct uploads with the content type header" do
    assert {:ok, upload} = S3.presign_upload("sfx/airhorn.mp3", "audio/mpeg")

    assert %{
             key: "sfx/airhorn.mp3",
             method: "PUT",
             headers: %{"content-type" => "audio/mpeg"},
             expires_in: 3600
           } = upload

    assert String.starts_with?(upload.url, "http://localhost:9000/bot-world/sfx/airhorn.mp3?")
    assert String.contains?(upload.url, "X-Amz-SignedHeaders=content-type%3Bhost")
  end

  defp temp_file_path do
    Path.join(System.tmp_dir!(), "bot-world-s3-test-#{System.unique_integer([:positive])}")
  end
end
