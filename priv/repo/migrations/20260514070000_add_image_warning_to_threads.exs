defmodule ForumAwsRekognition.Repo.Migrations.AddImageWarningToThreads do
  use Ecto.Migration

  def change do
    alter table(:threads) do
      add :image_warning, :string
    end
  end
end
