defmodule ForumAwsRekognition.Uploads do
  def upload_thread_image(local_path, client_name) do
    ext = Path.extname(client_name) |> String.downcase()
    filename = "threads/#{Ecto.UUID.generate()}#{ext}"
    r2 = Application.fetch_env!(:forum_aws_rekognition, :r2)
    bucket = r2[:bucket]
    public_url = r2[:public_url]

    result =
      local_path
      |> ExAws.S3.Upload.stream_file()
      |> ExAws.S3.upload(bucket, filename, content_type: content_type(ext))
      |> ExAws.request()

    case result do
      {:ok, _} -> {:ok, "#{public_url}/#{filename}"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp content_type(".jpg"), do: "image/jpeg"
  defp content_type(".jpeg"), do: "image/jpeg"
  defp content_type(".png"), do: "image/png"
  defp content_type(".gif"), do: "image/gif"
  defp content_type(".webp"), do: "image/webp"
  defp content_type(_), do: "application/octet-stream"
end
