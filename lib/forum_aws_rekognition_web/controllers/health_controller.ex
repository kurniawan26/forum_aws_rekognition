defmodule ForumAwsRekognitionWeb.HealthController do
  use ForumAwsRekognitionWeb, :controller

  def check(conn, _params) do
    json(conn, %{status: "ok"})
  end
end
