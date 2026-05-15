defmodule ForumAwsRekognition.Utils.Rekognition do
  require Logger

  @confidence_threshold 80.0

  @animal_labels %{
    "Cat" => "Gambar ini mengandung kucing. Pastikan hati kamu cukup kuat.",
    "Kitten" => "Gambar ini mengandung anak kucing. Risiko gemas sangat tinggi.",
    "Dog" => "Gambar ini mengandung anjing. Ekor bahagia menanti.",
    "Puppy" => "Gambar ini mengandung anak anjing. Tidak bertanggung jawab atas potensi \"aww\".",
    "Rabbit" => "Gambar ini mengandung kelinci. Siapkan keinginan untuk memelihara.",
    "Hamster" => "Gambar ini mengandung hamster. Pipi gembul di depan.",
    "Panda" => "Gambar ini mengandung panda. Kelucuan level nasional."
  }

  def detect_animal_warning(binary) do
    case call_detect_labels(binary) do
      {:ok, %{"Labels" => labels}} ->
        warning =
          labels
          |> Enum.map(& &1["Name"])
          |> Enum.find_value(fn name -> Map.get(@animal_labels, name) end)

        {:ok, warning}

      {:error, reason} ->
        Logger.error("[LabelDetection] Rekognition call failed: #{inspect(reason)}. Skipping warning.")
        {:ok, nil}
    end
  end

  def safe?(binary) do
    case call_rekognition(binary) do
      {:ok, %{"ModerationLabels" => []}} ->
        :ok

      {:ok, %{"ModerationLabels" => [top | _] = labels}} ->
        Logger.warning(
          "[ImageModeration] Flagged #{length(labels)} label(s). Top: #{top["Name"]} (#{Float.round(top["Confidence"] * 1.0, 1)}%)"
        )

        {:error, :unsafe_content}

      {:error, reason} ->
        Logger.error(
          "[ImageModeration] Rekognition call failed: #{inspect(reason)}. Failing open."
        )

        :ok
    end
  end

  # ==================== PRIVATE ====================

  defp call_detect_labels(binary) do
    operation = %ExAws.Operation.JSON{
      http_method: :post,
      service: :rekognition,
      headers: [
        {"content-type", "application/x-amz-json-1.1"},
        {"x-amz-target", "RekognitionService.DetectLabels"}
      ],
      data: %{
        "Image" => %{"Bytes" => Base.encode64(binary)},
        "MaxLabels" => 10,
        "MinConfidence" => @confidence_threshold
      },
      path: "/"
    }

    ExAws.request(operation, rekognition_config())
  end

  defp call_rekognition(binary) do
    operation = %ExAws.Operation.JSON{
      http_method: :post,
      service: :rekognition,
      headers: [
        {"content-type", "application/x-amz-json-1.1"},
        {"x-amz-target", "RekognitionService.DetectModerationLabels"}
      ],
      data: %{
        "Image" => %{"Bytes" => Base.encode64(binary)},
        "MinConfidence" => @confidence_threshold
      },
      path: "/"
    }

    ExAws.request(operation, rekognition_config())
  end

  defp rekognition_config do
    [
      region:
        System.get_env("AWS_REKOGNITION_REGION") ||
          Application.get_env(:shared_services, :rekognition_region) || "ap-southeast-1",
      access_key_id:
        System.get_env("AWS_REKOGNITION_ACCESS_KEY_ID") ||
          Application.get_env(:shared_services, :rekognition_access_key_id),
      secret_access_key:
        System.get_env("AWS_REKOGNITION_SECRET_ACCESS_KEY") ||
          Application.get_env(:shared_services, :rekognition_secret_access_key)
    ]
  end
end
