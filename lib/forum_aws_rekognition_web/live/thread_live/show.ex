defmodule ForumAwsRekognitionWeb.ThreadLive.Show do
  use ForumAwsRekognitionWeb, :live_view

  alias ForumAwsRekognition.Forum

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
          <div class="card-body gap-4 p-6 sm:p-8">
            <div class="flex items-start justify-between gap-4">
              <h1 class="text-2xl font-bold text-base-content leading-snug">{@thread.title}</h1>
              <.button variant="primary" navigate={~p"/threads/#{@thread}/edit?return_to=show"}>
                <.icon name="hero-pencil-square" class="size-4" /> Edit
              </.button>
            </div>
            <div class="divider my-0"></div>
            <p class="text-base-content/80 leading-relaxed whitespace-pre-wrap">{@thread.body}</p>
          </div>
        </article>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket) do
      Forum.subscribe_threads(socket.assigns.current_scope)
    end

    {:ok,
     socket
     |> assign(:page_title, "Thread")
     |> assign(:thread, Forum.get_thread!(socket.assigns.current_scope, id))}
  end

  @impl true
  def handle_info(
        {:updated, %ForumAwsRekognition.Forum.Thread{id: id} = thread},
        %{assigns: %{thread: %{id: id}}} = socket
      ) do
    {:noreply, assign(socket, :thread, thread)}
  end

  def handle_info(
        {:deleted, %ForumAwsRekognition.Forum.Thread{id: id}},
        %{assigns: %{thread: %{id: id}}} = socket
      ) do
    {:noreply,
     socket
     |> put_flash(:error, "This thread was deleted.")
     |> push_navigate(to: ~p"/threads")}
  end

  def handle_info({type, %ForumAwsRekognition.Forum.Thread{}}, socket)
      when type in [:created, :updated, :deleted] do
    {:noreply, socket}
  end
end
