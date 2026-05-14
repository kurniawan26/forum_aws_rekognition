defmodule ForumAwsRekognition.Repo do
  use Ecto.Repo,
    otp_app: :forum_aws_rekognition,
    adapter: Ecto.Adapters.Postgres
end
