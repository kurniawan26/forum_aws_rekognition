defmodule ForumAwsRekognition.Forum.Vote do
  use Ecto.Schema
  import Ecto.Changeset

  schema "votes" do
    field :value, :integer
    field :votable_type, :string
    field :votable_id, :integer

    belongs_to :user, ForumAwsRekognition.Accounts.User

    timestamps()
  end

  def changeset(vote, attrs) do
    vote
    |> cast(attrs, [:user_id, :value, :votable_type, :votable_id])
    |> validate_required([:user_id, :value, :votable_type, :votable_id])
    |> validate_inclusion(:value, [1, -1])
  end
end
