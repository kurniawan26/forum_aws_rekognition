defmodule ForumAwsRekognitionWeb.ThreadLive.Index do
  use ForumAwsRekognitionWeb, :live_view

  alias ForumAwsRekognition.Forum

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="flex items-center justify-between gap-4">
          <div>
            <h1 class="text-2xl font-bold text-base-content">Threads</h1>
            <p class="text-sm text-base-content/60 mt-0.5">Browse and join community discussions</p>
          </div>
          <.button variant="primary" navigate={~p"/threads/new"}>
            <.icon name="hero-plus" class="size-4" /> New Thread
          </.button>
        </div>

        <div class="space-y-3">
          <div
            :for={{id, thread} <- @streams.threads}
            id={id}
            class="card bg-base-100 border border-base-300 hover:border-primary hover:shadow-sm transition-all"
          >
            <div class="card-body p-5">
              <div class="flex items-start gap-4">
                <.link :if={thread.image_url} navigate={~p"/threads/#{thread}"} class="relative shrink-0">
                  <img
                    src={thread.image_url}
                    class={["size-16 rounded-lg object-cover border border-base-200", thread.image_warning && "blur-sm"]}
                  />
                  <div :if={thread.image_warning} class="absolute inset-0 rounded-lg flex items-center justify-center bg-base-100/40" title={thread.image_warning}>
                    <.icon name="hero-eye-slash" class="size-5 text-base-content/70" />
                  </div>
                </.link>
                <div class="flex-1 min-w-0">
                  <.link navigate={~p"/threads/#{thread}"} class="block group">
                    <h2 class="font-semibold text-base-content group-hover:text-primary transition-colors">
                      {thread.title}
                    </h2>
                    <p class="text-sm text-base-content/60 mt-1 line-clamp-2">{thread.body}</p>
                  </.link>
                </div>
                <div :if={thread.user_id == @current_scope.user.id} class="flex gap-1 shrink-0">
                  <.link navigate={~p"/threads/#{thread}/edit"} class="btn btn-ghost btn-xs" title="Edit">
                    <.icon name="hero-pencil" class="size-3.5" />
                  </.link>
                  <.link
                    phx-click={JS.push("delete", value: %{id: thread.id}) |> hide("##{id}")}
                    data-confirm="Are you sure you want to delete this thread?"
                    class="btn btn-ghost btn-xs text-error"
                    title="Delete"
                  >
                    <.icon name="hero-trash" class="size-3.5" />
                  </.link>
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
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Forum.subscribe_threads(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Threads")
     |> stream(:threads, list_threads(socket.assigns.current_scope))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    thread = Forum.get_thread!(socket.assigns.current_scope, id)
    {:ok, _} = Forum.delete_thread(socket.assigns.current_scope, thread)

    {:noreply, stream_delete(socket, :threads, thread)}
  end

  @impl true
  def handle_info({type, %ForumAwsRekognition.Forum.Thread{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, stream(socket, :threads, list_threads(socket.assigns.current_scope), reset: true)}
  end

  defp list_threads(current_scope) do
    Forum.list_threads(current_scope)
  end
end
