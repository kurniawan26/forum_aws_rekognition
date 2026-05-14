defmodule ForumAwsRekognition.Forum.Thread do
  use Ecto.Schema
  import Ecto.Changeset

  schema "threads" do
    field :title, :string
    field :body, :string
    belongs_to :user, ForumAwsRekognition.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(thread, attrs, user_scope) do
    thread
    |> cast(attrs, [:title, :body])
    |> validate_required([:title, :body])
    |> put_change(:user_id, user_scope.user.id)
  end
end
