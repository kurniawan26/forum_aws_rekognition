defmodule ForumAwsRekognitionWeb.ThreadLive.Form do
  use ForumAwsRekognitionWeb, :live_view

  alias ForumAwsRekognition.Forum
  alias ForumAwsRekognition.Forum.Thread

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="space-y-6">
        <div class="flex items-center gap-2 text-sm text-base-content/60">
          <.link navigate={return_path(@current_scope, @return_to, @thread)} class="hover:text-primary transition-colors flex items-center gap-1">
            <.icon name="hero-arrow-left" class="size-4" />
            {if @return_to == "show", do: @thread.title, else: "Threads"}
          </.link>
          <span>/</span>
          <span class="text-base-content">{@page_title}</span>
        </div>

        <div class="card bg-base-100 border border-base-300">
          <div class="card-body p-6 sm:p-8">
            <h1 class="text-xl font-bold text-base-content mb-4">{@page_title}</h1>
            <.form for={@form} id="thread-form" phx-change="validate" phx-submit="save" class="space-y-4">
              <.input field={@form[:title]} type="text" label="Title" placeholder="Give your thread a clear title..." />
              <.input field={@form[:body]} type="textarea" label="Body" rows="6" placeholder="Share your thoughts..." />
              <div class="flex gap-3 pt-2">
                <.button phx-disable-with="Saving..." variant="primary">Save Thread</.button>
                <.button navigate={return_path(@current_scope, @return_to, @thread)}>Cancel</.button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    thread = Forum.get_thread!(socket.assigns.current_scope, id)

    socket
    |> assign(:page_title, "Edit Thread")
    |> assign(:thread, thread)
    |> assign(:form, to_form(Forum.change_thread(socket.assigns.current_scope, thread)))
  end

  defp apply_action(socket, :new, _params) do
    thread = %Thread{user_id: socket.assigns.current_scope.user.id}

    socket
    |> assign(:page_title, "New Thread")
    |> assign(:thread, thread)
    |> assign(:form, to_form(Forum.change_thread(socket.assigns.current_scope, thread)))
  end

  @impl true
  def handle_event("validate", %{"thread" => thread_params}, socket) do
    changeset = Forum.change_thread(socket.assigns.current_scope, socket.assigns.thread, thread_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"thread" => thread_params}, socket) do
    save_thread(socket, socket.assigns.live_action, thread_params)
  end

  defp save_thread(socket, :edit, thread_params) do
    case Forum.update_thread(socket.assigns.current_scope, socket.assigns.thread, thread_params) do
      {:ok, thread} ->
        {:noreply,
         socket
         |> put_flash(:info, "Thread updated successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, thread)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_thread(socket, :new, thread_params) do
    case Forum.create_thread(socket.assigns.current_scope, thread_params) do
      {:ok, thread} ->
        {:noreply,
         socket
         |> put_flash(:info, "Thread created successfully")
         |> push_navigate(
           to: return_path(socket.assigns.current_scope, socket.assigns.return_to, thread)
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path(_scope, "index", _thread), do: ~p"/threads"
  defp return_path(_scope, "show", thread), do: ~p"/threads/#{thread}"
end
