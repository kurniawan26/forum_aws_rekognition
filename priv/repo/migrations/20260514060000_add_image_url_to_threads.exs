defmodule ForumAwsRekognition.Repo.Migrations.AddImageUrlToThreads do
  use Ecto.Migration

  def change do
    alter table(:threads) do
      add :image_url, :string
    end
  end
end
