defmodule ForumAwsRekognition.Forum.Thread do
  use Ecto.Schema
  import Ecto.Changeset

  schema "threads" do
    field :title, :string
    field :body, :string
    field :image_url, :string
    field :image_warning, :string
    belongs_to :user, ForumAwsRekognition.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(thread, attrs, user_scope) do
    thread
    |> cast(attrs, [:title, :body, :image_url, :image_warning])
    |> validate_required([:title, :body])
    |> put_change(:user_id, user_scope.user.id)
  end
end
