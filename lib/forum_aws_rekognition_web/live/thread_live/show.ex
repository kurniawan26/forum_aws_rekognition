defmodule ForumAwsRekognitionWeb.ThreadLive.Show do
  use ForumAwsRekognitionWeb, :live_view

  alias ForumAwsRekognition.Forum
  alias ForumAwsRekognition.Forum.Comment

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="flex items-center gap-2 text-sm text-base-content/60">
          <.link navigate={~p"/threads"} class="hover:text-primary transition-colors flex items-center gap-1">
            <.icon name="hero-arrow-left" class="size-4" /> Threads
          </.link>
          <span>/</span>
          <span class="text-base-content truncate max-w-xs">{@thread.title}</span>
        </div>

        <article class="card bg-base-100 border border-base-300">
          <div :if={@thread.image_url} class="overflow-hidden rounded-t-2xl relative">
            <img
              id="thread-cover-image"
              src={@thread.image_url}
              class={["w-full max-h-80 object-cover transition-all duration-500", @thread.image_warning && "blur-xl"]}
            />
            <div
              :if={@thread.image_warning}
              id="image-warning-overlay"
              class="absolute inset-0 flex flex-col items-center justify-center gap-3 p-6 bg-base-100/60 backdrop-blur-sm"
            >
              <.icon name="hero-exclamation-triangle" class="size-8 text-warning" />
              <p class="text-sm font-medium text-center text-base-content max-w-sm leading-relaxed">
                {@thread.image_warning}
              </p>
              <button
                class="btn btn-sm btn-primary"
                phx-click={
                  JS.remove_class("blur-xl", to: "#thread-cover-image")
                  |> JS.hide(to: "#image-warning-overlay")
                }
              >
                <.icon name="hero-eye" class="size-4" /> Lihat Gambar
              </button>
            </div>
          </div>
          <div class="card-body gap-4 p-6 sm:p-8">
            <div class="flex gap-4">
              <div class="flex flex-col items-center gap-1 shrink-0 pt-1">
                <button
                  phx-click="vote_thread"
                  phx-value-vote="1"
                  title="Upvote"
                  class={[
                    "btn btn-ghost btn-xs",
                    @my_thread_vote && @my_thread_vote.value == 1 && "text-primary"
                  ]}
                >
                  <.icon name="hero-arrow-up" class="size-4" />
                </button>
                <span class="text-sm font-bold tabular-nums">{@thread_score}</span>
                <button
                  phx-click="vote_thread"
                  phx-value-vote="-1"
                  title="Downvote"
                  class={[
                    "btn btn-ghost btn-xs",
                    @my_thread_vote && @my_thread_vote.value == -1 && "text-error"
                  ]}
                >
                  <.icon name="hero-arrow-down" class="size-4" />
                </button>
              </div>

              <div class="flex-1 min-w-0">
                <div class="flex items-start justify-between gap-4">
                  <h1 class="text-2xl font-bold text-base-content leading-snug">{@thread.title}</h1>
                  <.button :if={@thread.user_id == @current_scope.user.id} variant="primary" navigate={~p"/threads/#{@thread}/edit?return_to=show"}>
                    <.icon name="hero-pencil-square" class="size-4" /> Edit
                  </.button>
                </div>
                <div class="flex items-center gap-2 text-xs text-base-content/40">
                  <.icon name="hero-user-circle" class="size-3.5" />
                  <span class="font-medium">{author_name(@thread.user.email)}</span>
                  <span>·</span>
                  <span>{format_time(@thread.inserted_at)}</span>
                </div>
                <div class="divider my-1"></div>
                <p class="text-base-content/80 leading-relaxed whitespace-pre-wrap">{@thread.body}</p>
              </div>
            </div>
          </div>
        </article>

        <div class="space-y-4">
          <h2 class="font-semibold text-lg text-base-content">
            {length(@comments)} {if length(@comments) == 1, do: "Comment", else: "Comments"}
          </h2>

          <div class="card bg-base-100 border border-base-300">
            <div class="card-body p-4">
              <.form for={@comment_form} phx-submit="add_comment" phx-change="validate_comment" id="comment-form">
                <.input
                  field={@comment_form[:body]}
                  type="textarea"
                  placeholder="Share your thoughts..."
                  rows="3"
                />
                <div class="flex justify-end mt-2">
                  <.button variant="primary" phx-disable-with="Posting...">
                    <.icon name="hero-paper-airplane" class="size-4" /> Post Comment
                  </.button>
                </div>
              </.form>
            </div>
          </div>

          <div class="space-y-3" id="comments">
            <div :for={comment <- @comments} id={"comment-#{comment.id}"}>
              <div class="card bg-base-100 border border-base-300">
                <div class="card-body p-4 gap-3">
                  <div class="flex gap-3">
                    <div class="flex flex-col items-center gap-0.5 shrink-0">
                      <button
                        phx-click="vote_comment"
                        phx-value-id={comment.id}
                        phx-value-vote="1"
                        class={[
                          "btn btn-ghost btn-xs",
                          Map.get(@my_comment_votes, comment.id) == 1 && "text-primary"
                        ]}
                      >
                        <.icon name="hero-arrow-up" class="size-3.5" />
                      </button>
                      <span class="text-xs font-bold tabular-nums">
                        {Map.get(@comment_scores, comment.id, 0)}
                      </span>
                      <button
                        phx-click="vote_comment"
                        phx-value-id={comment.id}
                        phx-value-vote="-1"
                        class={[
                          "btn btn-ghost btn-xs",
                          Map.get(@my_comment_votes, comment.id) == -1 && "text-error"
                        ]}
                      >
                        <.icon name="hero-arrow-down" class="size-3.5" />
                      </button>
                    </div>

                    <div class="flex-1 min-w-0">
                      <div class="flex items-center gap-1.5 mb-1.5">
                        <span class="text-xs font-semibold text-base-content/70">{author_name(comment.user.email)}</span>
                        <span class="text-xs text-base-content/30">·</span>
                        <span class="text-xs text-base-content/40">{format_time(comment.inserted_at)}</span>
                      </div>
                      <p class="text-sm text-base-content leading-relaxed">{comment.body}</p>
                      <div class="flex gap-2 mt-2">
                        <button
                          phx-click="start_reply"
                          phx-value-id={comment.id}
                          class="btn btn-ghost btn-xs gap-1 text-base-content/60"
                        >
                          <.icon name="hero-chat-bubble-left" class="size-3.5" /> Reply
                        </button>
                        <button
                          :if={comment.user_id == @current_scope.user.id}
                          phx-click="delete_comment"
                          phx-value-id={comment.id}
                          data-confirm="Delete this comment?"
                          class="btn btn-ghost btn-xs text-error/60 hover:text-error"
                        >
                          <.icon name="hero-trash" class="size-3.5" />
                        </button>
                      </div>
                    </div>
                  </div>

                  <div :if={@reply_to_id == comment.id} class="ml-8 pt-3 border-t border-base-300">
                    <.form
                      for={@reply_form}
                      phx-submit="add_reply"
                      phx-change="validate_reply"
                      id={"reply-form-#{comment.id}"}
                    >
                      <.input
                        field={@reply_form[:body]}
                        type="textarea"
                        placeholder="Write a reply..."
                        rows="2"
                      />
                      <div class="flex gap-2 mt-2 justify-end">
                        <.button phx-click="cancel_reply" type="button">Cancel</.button>
                        <.button variant="primary" phx-disable-with="Posting...">Reply</.button>
                      </div>
                    </.form>
                  </div>

                  <div :if={comment.replies != []} class="ml-8 space-y-2 pt-3 border-t border-base-300">
                    <div :for={reply <- comment.replies} id={"comment-#{reply.id}"} class="flex gap-3">
                      <div class="flex flex-col items-center gap-0.5 shrink-0">
                        <button
                          phx-click="vote_comment"
                          phx-value-id={reply.id}
                          phx-value-vote="1"
                          class={[
                            "btn btn-ghost btn-xs",
                            Map.get(@my_comment_votes, reply.id) == 1 && "text-primary"
                          ]}
                        >
                          <.icon name="hero-arrow-up" class="size-3.5" />
                        </button>
                        <span class="text-xs font-bold tabular-nums">
                          {Map.get(@comment_scores, reply.id, 0)}
                        </span>
                        <button
                          phx-click="vote_comment"
                          phx-value-id={reply.id}
                          phx-value-vote="-1"
                          class={[
                            "btn btn-ghost btn-xs",
                            Map.get(@my_comment_votes, reply.id) == -1 && "text-error"
                          ]}
                        >
                          <.icon name="hero-arrow-down" class="size-3.5" />
                        </button>
                      </div>

                      <div class="flex-1 min-w-0 bg-base-200 rounded-lg p-3">
                        <div class="flex items-center gap-1.5 mb-1.5">
                          <span class="text-xs font-semibold text-base-content/70">{author_name(reply.user.email)}</span>
                          <span class="text-xs text-base-content/30">·</span>
                          <span class="text-xs text-base-content/40">{format_time(reply.inserted_at)}</span>
                        </div>
                        <p class="text-sm text-base-content leading-relaxed">{reply.body}</p>
                        <button
                          :if={reply.user_id == @current_scope.user.id}
                          phx-click="delete_comment"
                          phx-value-id={reply.id}
                          data-confirm="Delete this reply?"
                          class="btn btn-ghost btn-xs text-error/60 hover:text-error mt-1"
                        >
                          <.icon name="hero-trash" class="size-3.5" />
                        </button>
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    thread = Forum.get_thread!(socket.assigns.current_scope, id)

    if connected?(socket) do
      Forum.subscribe_threads(socket.assigns.current_scope)
      Forum.subscribe_thread_comments(thread.id)
    end

    {:ok,
     socket
     |> assign(:page_title, thread.title)
     |> assign(:thread, thread)
     |> assign(:comment_form, to_form(Forum.change_comment(%Comment{})))
     |> assign(:reply_to_id, nil)
     |> assign(:reply_form, nil)
     |> load_thread_votes()
     |> load_comments()}
  end

  @impl true
  def handle_event("vote_thread", %{"vote" => value_str}, socket) do
    user_id = socket.assigns.current_scope.user.id
    thread_id = socket.assigns.thread.id

    Forum.cast_vote(user_id, "thread", thread_id, String.to_integer(value_str))

    {:noreply, load_thread_votes(socket)}
  end

  def handle_event("vote_comment", %{"id" => id_str, "vote" => value_str}, socket) do
    user_id = socket.assigns.current_scope.user.id

    Forum.cast_vote(user_id, "comment", String.to_integer(id_str), String.to_integer(value_str))

    {:noreply, load_comment_votes(socket)}
  end

  def handle_event("validate_comment", %{"comment" => params}, socket) do
    changeset = Forum.change_comment(%Comment{}, params)
    {:noreply, assign(socket, :comment_form, to_form(changeset, action: :validate))}
  end

  def handle_event("add_comment", %{"comment" => %{"body" => body}}, socket) do
    user_id = socket.assigns.current_scope.user.id
    thread_id = socket.assigns.thread.id

    case Forum.create_comment(user_id, thread_id, body) do
      {:ok, _comment} ->
        {:noreply,
         socket
         |> assign(:comment_form, to_form(Forum.change_comment(%Comment{})))
         |> load_comments()}

      {:error, changeset} ->
        {:noreply, assign(socket, :comment_form, to_form(changeset, action: :validate))}
    end
  end

  def handle_event("start_reply", %{"id" => id_str}, socket) do
    {:noreply,
     socket
     |> assign(:reply_to_id, String.to_integer(id_str))
     |> assign(:reply_form, to_form(Forum.change_comment(%Comment{}), as: "reply"))}
  end

  def handle_event("cancel_reply", _, socket) do
    {:noreply, assign(socket, reply_to_id: nil, reply_form: nil)}
  end

  def handle_event("validate_reply", %{"reply" => params}, socket) do
    changeset = Forum.change_comment(%Comment{}, params)
    {:noreply, assign(socket, :reply_form, to_form(changeset, action: :validate, as: "reply"))}
  end

  def handle_event("add_reply", %{"reply" => %{"body" => body}}, socket) do
    user_id = socket.assigns.current_scope.user.id
    thread_id = socket.assigns.thread.id
    parent_id = socket.assigns.reply_to_id

    case Forum.create_comment(user_id, thread_id, body, parent_id) do
      {:ok, _comment} ->
        {:noreply,
         socket
         |> assign(:reply_to_id, nil)
         |> assign(:reply_form, nil)
         |> load_comments()}

      {:error, changeset} ->
        {:noreply, assign(socket, :reply_form, to_form(changeset, action: :validate, as: "reply"))}
    end
  end

  def handle_event("delete_comment", %{"id" => id_str}, socket) do
    user_id = socket.assigns.current_scope.user.id
    comment = Forum.get_comment!(String.to_integer(id_str))

    case Forum.delete_comment(user_id, comment) do
      {:ok, _} -> {:noreply, load_comments(socket)}
      _ -> {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:updated, %ForumAwsRekognition.Forum.Thread{id: id} = thread},
        %{assigns: %{thread: %{id: id}}} = socket) do
    {:noreply, assign(socket, :thread, thread)}
  end

  def handle_info({:deleted, %ForumAwsRekognition.Forum.Thread{id: id}},
        %{assigns: %{thread: %{id: id}}} = socket) do
    {:noreply,
     socket
     |> put_flash(:error, "This thread was deleted.")
     |> push_navigate(to: ~p"/threads")}
  end

  def handle_info({type, %ForumAwsRekognition.Forum.Thread{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end

  def handle_info({type, %Comment{}}, socket)
      when type in [:comment_created, :comment_deleted] do
    {:noreply, load_comments(socket)}
  end

  # ---------------------------------------------------------------------------
  # Private helpers
  # ---------------------------------------------------------------------------

  defp load_comments(socket) do
    thread_id = socket.assigns.thread.id
    comments = Forum.list_thread_comments(thread_id)

    socket
    |> assign(:comments, comments)
    |> load_comment_votes()
  end

  defp load_comment_votes(socket) do
    user_id = socket.assigns.current_scope.user.id
    comment_ids = all_comment_ids(socket.assigns.comments)

    socket
    |> assign(:comment_scores, Forum.get_vote_scores("comment", comment_ids))
    |> assign(:my_comment_votes, Forum.get_user_votes(user_id, "comment", comment_ids))
  end

  defp load_thread_votes(socket) do
    user_id = socket.assigns.current_scope.user.id
    thread_id = socket.assigns.thread.id

    socket
    |> assign(:thread_score, Forum.get_vote_score("thread", thread_id))
    |> assign(:my_thread_vote, Forum.get_user_vote(user_id, "thread", thread_id))
  end

  defp all_comment_ids(comments) do
    Enum.flat_map(comments, fn c -> [c.id | Enum.map(c.replies, & &1.id)] end)
  end

  defp format_time(%DateTime{} = dt), do: dt |> DateTime.to_naive() |> format_time()

  defp format_time(%NaiveDateTime{} = dt) do
    Calendar.strftime(dt, "%b %d, %Y · %H:%M")
  end

  defp author_name(email) do
    email |> String.split("@") |> List.first()
  end
end
