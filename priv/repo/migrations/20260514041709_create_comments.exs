defmodule ForumAwsRekognition.Repo.Migrations.CreateComments do
  use Ecto.Migration

  def change do
    create table(:comments) do
      add :body, :text, null: false
      add :thread_id, references(:threads, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :parent_id, references(:comments, on_delete: :delete_all)
      timestamps()
    end

    create index(:comments, [:thread_id])
    create index(:comments, [:parent_id])
  end
end
