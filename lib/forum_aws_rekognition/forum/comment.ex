defmodule ForumAwsRekognition.Forum.Comment do
  use Ecto.Schema
  import Ecto.Changeset

  schema "comments" do
    field :body, :string
    belongs_to :user, ForumAwsRekognition.Accounts.User
    belongs_to :thread, ForumAwsRekognition.Forum.Thread
    belongs_to :parent, ForumAwsRekognition.Forum.Comment
    has_many :replies, ForumAwsRekognition.Forum.Comment, foreign_key: :parent_id

    has_many :votes, ForumAwsRekognition.Forum.Vote,
      foreign_key: :votable_id,
      where: [votable_type: "comment"],
      on_delete: :delete_all

    timestamps()
  end

  def changeset(comment, attrs) do
    comment
    |> cast(attrs, [:body, :thread_id, :user_id, :parent_id])
    |> validate_required([:body, :thread_id, :user_id])
    |> validate_length(:body, min: 1, max: 2000)
  end
end
