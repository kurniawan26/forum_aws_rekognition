defmodule ForumAwsRekognition.Forum do
  @moduledoc """
  The Forum context.
  """

  import Ecto.Query, warn: false
  alias ForumAwsRekognition.Repo

  alias ForumAwsRekognition.Accounts.Scope
  alias ForumAwsRekognition.Forum.Thread
  alias ForumAwsRekognition.Forum.Post
  alias ForumAwsRekognition.Forum.Comment
  alias ForumAwsRekognition.Forum.Vote

  # ---------------------------------------------------------------------------
  # Thread PubSub
  # ---------------------------------------------------------------------------

  def subscribe_threads(_scope \\ nil) do
    Phoenix.PubSub.subscribe(ForumAwsRekognition.PubSub, "threads")
  end

  defp broadcast_thread(_scope, message) do
    Phoenix.PubSub.broadcast(ForumAwsRekognition.PubSub, "threads", message)
  end

  # ---------------------------------------------------------------------------
  # Thread CRUD
  # ---------------------------------------------------------------------------

  def list_threads(_scope \\ nil) do
    from(t in Thread, order_by: [desc: t.inserted_at], preload: [:user])
    |> Repo.all()
  end

  def get_thread!(_scope \\ nil, id) do
    Thread
    |> Repo.get!(to_id(id))
    |> Repo.preload(:user)
  end

  def create_thread(%Scope{} = scope, attrs) do
    with {:ok, thread = %Thread{}} <-
           %Thread{}
           |> Thread.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_thread(scope, {:created, thread})
      {:ok, thread}
    end
  end

  def update_thread(%Scope{} = scope, %Thread{} = thread, attrs) do
    true = thread.user_id == scope.user.id

    with {:ok, thread = %Thread{}} <-
           thread
           |> Thread.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_thread(scope, {:updated, thread})
      {:ok, thread}
    end
  end

  def delete_thread(%Scope{} = scope, %Thread{} = thread) do
    true = thread.user_id == scope.user.id

    with {:ok, thread = %Thread{}} <- Repo.delete(thread) do
      broadcast_thread(scope, {:deleted, thread})
      {:ok, thread}
    end
  end

  def change_thread(%Scope{} = scope, %Thread{} = thread, attrs \\ %{}) do
    Thread.changeset(thread, attrs, scope)
  end

  # ---------------------------------------------------------------------------
  # Comment PubSub
  # ---------------------------------------------------------------------------

  def subscribe_thread_comments(thread_id) do
    Phoenix.PubSub.subscribe(ForumAwsRekognition.PubSub, "thread:#{thread_id}:comments")
  end

  defp broadcast_comment(thread_id, message) do
    Phoenix.PubSub.broadcast(ForumAwsRekognition.PubSub, "thread:#{thread_id}:comments", message)
  end

  # ---------------------------------------------------------------------------
  # Comment CRUD
  # ---------------------------------------------------------------------------

  def list_thread_comments(thread_id) do
    replies_query = from(r in Comment, preload: [:user], order_by: [asc: r.inserted_at])

    from(c in Comment,
      where: c.thread_id == ^thread_id and is_nil(c.parent_id),
      preload: [:user, replies: ^replies_query],
      order_by: [asc: c.inserted_at]
    )
    |> Repo.all()
  end

  def get_comment!(id), do: Repo.get!(Comment, to_id(id))

  defp to_id(id) when is_integer(id), do: id
  defp to_id(id) when is_binary(id), do: String.to_integer(id)

  def create_comment(user_id, thread_id, body, parent_id \\ nil) do
    attrs = %{body: body, thread_id: thread_id, user_id: user_id, parent_id: parent_id}

    with {:ok, comment} <- %Comment{} |> Comment.changeset(attrs) |> Repo.insert() do
      broadcast_comment(thread_id, {:comment_created, comment})
      {:ok, comment}
    end
  end

  def delete_comment(user_id, %Comment{} = comment) do
    true = comment.user_id == user_id

    with {:ok, comment} <- Repo.delete(comment) do
      broadcast_comment(comment.thread_id, {:comment_deleted, comment})
      {:ok, comment}
    end
  end

  def change_comment(%Comment{} = comment, attrs \\ %{}) do
    comment
    |> Ecto.Changeset.cast(attrs, [:body])
    |> Ecto.Changeset.validate_required([:body])
    |> Ecto.Changeset.validate_length(:body, min: 1, max: 2000)
  end

  # ---------------------------------------------------------------------------
  # Vote functions
  # ---------------------------------------------------------------------------

  def get_vote_score(votable_type, votable_id) do
    from(v in Vote,
      where: v.votable_type == ^votable_type and v.votable_id == ^votable_id,
      select: sum(v.value)
    )
    |> Repo.one()
    |> Kernel.||(0)
  end

  def get_vote_scores(_votable_type, []), do: %{}

  def get_vote_scores(votable_type, votable_ids) do
    from(v in Vote,
      where: v.votable_type == ^votable_type and v.votable_id in ^votable_ids,
      group_by: v.votable_id,
      select: {v.votable_id, sum(v.value)}
    )
    |> Repo.all()
    |> Map.new()
  end

  def get_user_vote(user_id, votable_type, votable_id) do
    Repo.get_by(Vote, user_id: user_id, votable_type: votable_type, votable_id: votable_id)
  end

  def get_user_votes(_user_id, _votable_type, []), do: %{}

  def get_user_votes(user_id, votable_type, votable_ids) do
    from(v in Vote,
      where:
        v.user_id == ^user_id and v.votable_type == ^votable_type and
          v.votable_id in ^votable_ids,
      select: {v.votable_id, v.value}
    )
    |> Repo.all()
    |> Map.new()
  end

  def cast_vote(user_id, votable_type, votable_id, value) do
    existing =
      Repo.get_by(Vote,
        user_id: user_id,
        votable_type: votable_type,
        votable_id: votable_id
      )

    case existing do
      nil ->
        %Vote{}
        |> Vote.changeset(%{
          user_id: user_id,
          votable_type: votable_type,
          votable_id: votable_id,
          value: value
        })
        |> Repo.insert()

      vote when vote.value == value ->
        Repo.delete(vote)

      vote ->
        vote |> Vote.changeset(%{value: value}) |> Repo.update()
    end
  end

  # ---------------------------------------------------------------------------
  # Post CRUD
  # ---------------------------------------------------------------------------

  def subscribe_posts(%Scope{} = scope) do
    Phoenix.PubSub.subscribe(ForumAwsRekognition.PubSub, "user:#{scope.user.id}:posts")
  end

  defp broadcast_post(%Scope{} = scope, message) do
    Phoenix.PubSub.broadcast(ForumAwsRekognition.PubSub, "user:#{scope.user.id}:posts", message)
  end

  def list_posts(%Scope{} = scope) do
    Repo.all_by(Post, user_id: scope.user.id)
  end

  def get_post!(%Scope{} = scope, id) do
    Repo.get_by!(Post, id: id, user_id: scope.user.id)
  end

  def create_post(%Scope{} = scope, attrs) do
    with {:ok, post = %Post{}} <-
           %Post{}
           |> Post.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_post(scope, {:created, post})
      {:ok, post}
    end
  end

  def update_post(%Scope{} = scope, %Post{} = post, attrs) do
    true = post.user_id == scope.user.id

    with {:ok, post = %Post{}} <-
           post
           |> Post.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_post(scope, {:updated, post})
      {:ok, post}
    end
  end

  def delete_post(%Scope{} = scope, %Post{} = post) do
    true = post.user_id == scope.user.id

    with {:ok, post = %Post{}} <- Repo.delete(post) do
      broadcast_post(scope, {:deleted, post})
      {:ok, post}
    end
  end

  def change_post(%Scope{} = scope, %Post{} = post, attrs \\ %{}) do
    true = post.user_id == scope.user.id
    Post.changeset(post, attrs, scope)
  end
end
