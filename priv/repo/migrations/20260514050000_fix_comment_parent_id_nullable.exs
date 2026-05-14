defmodule ForumAwsRekognition.Repo.Migrations.FixCommentParentIdNullable do
  use Ecto.Migration

  def up do
    execute "ALTER TABLE comments ALTER COLUMN parent_id DROP NOT NULL"
  end

  def down do
    execute "ALTER TABLE comments ALTER COLUMN parent_id SET NOT NULL"
  end
end
