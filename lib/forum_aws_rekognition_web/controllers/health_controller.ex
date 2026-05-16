defmodule ForumAwsRekognitionWeb.HealthController do
  use ForumAwsRekognitionWeb, :controller

  def check(conn, _params) do
    case db_connected?() do
      true ->
        json(conn, %{status: "ok"})

      false ->
        conn
        |> put_status(:service_unavailable)
        |> json(%{status: "error", reason: "database unavailable"})
    end
  end

  defp db_connected? do
    ForumAwsRekognition.Repo.query!("SELECT 1")
    true
  rescue
    _ -> false
  end
end
