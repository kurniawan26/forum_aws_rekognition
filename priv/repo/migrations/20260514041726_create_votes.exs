defmodule ForumAwsRekognition.Repo.Migrations.CreateVotes do
  use Ecto.Migration

  def change do
    create table(:votes) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :value, :smallint, null: false
      add :votable_type, :string, null: false
      add :votable_id, :integer, null: false
      timestamps()
    end

    create unique_index(:votes, [:user_id, :votable_type, :votable_id])
    create index(:votes, [:votable_type, :votable_id])
  end
end
