defmodule ForumAwsRekognition.Forum do
  @moduledoc """
  The Forum context.
  """

  import Ecto.Query, warn: false
  alias ForumAwsRekognition.Repo

  alias ForumAwsRekognition.Forum.Thread
  alias ForumAwsRekognition.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any thread changes.

  The broadcasted messages match the pattern:

    * {:created, %Thread{}}
    * {:updated, %Thread{}}
    * {:deleted, %Thread{}}

  """
  def subscribe_threads(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(ForumAwsRekognition.PubSub, "user:#{key}:threads")
  end

  defp broadcast_thread(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(ForumAwsRekognition.PubSub, "user:#{key}:threads", message)
  end

  @doc """
  Returns the list of threads.

  ## Examples

      iex> list_threads(scope)
      [%Thread{}, ...]

  """
  def list_threads(%Scope{} = scope) do
    Repo.all_by(Thread, user_id: scope.user.id)
  end

  @doc """
  Gets a single thread.

  Raises `Ecto.NoResultsError` if the Thread does not exist.

  ## Examples

      iex> get_thread!(scope, 123)
      %Thread{}

      iex> get_thread!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_thread!(%Scope{} = scope, id) do
    Repo.get_by!(Thread, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a thread.

  ## Examples

      iex> create_thread(scope, %{field: value})
      {:ok, %Thread{}}

      iex> create_thread(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_thread(%Scope{} = scope, attrs) do
    with {:ok, thread = %Thread{}} <-
           %Thread{}
           |> Thread.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_thread(scope, {:created, thread})
      {:ok, thread}
    end
  end

  @doc """
  Updates a thread.

  ## Examples

      iex> update_thread(scope, thread, %{field: new_value})
      {:ok, %Thread{}}

      iex> update_thread(scope, thread, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
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

  @doc """
  Deletes a thread.

  ## Examples

      iex> delete_thread(scope, thread)
      {:ok, %Thread{}}

      iex> delete_thread(scope, thread)
      {:error, %Ecto.Changeset{}}

  """
  def delete_thread(%Scope{} = scope, %Thread{} = thread) do
    true = thread.user_id == scope.user.id

    with {:ok, thread = %Thread{}} <-
           Repo.delete(thread) do
      broadcast_thread(scope, {:deleted, thread})
      {:ok, thread}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking thread changes.

  ## Examples

      iex> change_thread(scope, thread)
      %Ecto.Changeset{data: %Thread{}}

  """
  def change_thread(%Scope{} = scope, %Thread{} = thread, attrs \\ %{}) do
    true = thread.user_id == scope.user.id

    Thread.changeset(thread, attrs, scope)
  end

  alias ForumAwsRekognition.Forum.Post
  alias ForumAwsRekognition.Accounts.Scope

  @doc """
  Subscribes to scoped notifications about any post changes.

  The broadcasted messages match the pattern:

    * {:created, %Post{}}
    * {:updated, %Post{}}
    * {:deleted, %Post{}}

  """
  def subscribe_posts(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(ForumAwsRekognition.PubSub, "user:#{key}:posts")
  end

  defp broadcast_post(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(ForumAwsRekognition.PubSub, "user:#{key}:posts", message)
  end

  @doc """
  Returns the list of posts.

  ## Examples

      iex> list_posts(scope)
      [%Post{}, ...]

  """
  def list_posts(%Scope{} = scope) do
    Repo.all_by(Post, user_id: scope.user.id)
  end

  @doc """
  Gets a single post.

  Raises `Ecto.NoResultsError` if the Post does not exist.

  ## Examples

      iex> get_post!(scope, 123)
      %Post{}

      iex> get_post!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_post!(%Scope{} = scope, id) do
    Repo.get_by!(Post, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a post.

  ## Examples

      iex> create_post(scope, %{field: value})
      {:ok, %Post{}}

      iex> create_post(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_post(%Scope{} = scope, attrs) do
    with {:ok, post = %Post{}} <-
           %Post{}
           |> Post.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_post(scope, {:created, post})
      {:ok, post}
    end
  end

  @doc """
  Updates a post.

  ## Examples

      iex> update_post(scope, post, %{field: new_value})
      {:ok, %Post{}}

      iex> update_post(scope, post, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
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

  @doc """
  Deletes a post.

  ## Examples

      iex> delete_post(scope, post)
      {:ok, %Post{}}

      iex> delete_post(scope, post)
      {:error, %Ecto.Changeset{}}

  """
  def delete_post(%Scope{} = scope, %Post{} = post) do
    true = post.user_id == scope.user.id

    with {:ok, post = %Post{}} <-
           Repo.delete(post) do
      broadcast_post(scope, {:deleted, post})
      {:ok, post}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking post changes.

  ## Examples

      iex> change_post(scope, post)
      %Ecto.Changeset{data: %Post{}}

  """
  def change_post(%Scope{} = scope, %Post{} = post, attrs \\ %{}) do
    true = post.user_id == scope.user.id

    Post.changeset(post, attrs, scope)
  end
end
