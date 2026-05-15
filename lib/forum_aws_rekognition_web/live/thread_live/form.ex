defmodule ForumAwsRekognitionWeb.ThreadLive.Form do
  use ForumAwsRekognitionWeb, :live_view

  alias ForumAwsRekognition.Forum
  alias ForumAwsRekognition.Forum.Thread
  alias ForumAwsRekognition.Uploads
  alias ForumAwsRekognition.Utils.Rekognition

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

              <div>
                <label class="label mb-1.5 block text-sm font-medium text-base-content">Cover Image</label>

                <div
                  class="border-2 border-dashed border-base-300 rounded-xl p-8 text-center hover:border-primary transition-colors"
                  phx-drop-target={@uploads.image.ref}
                >
                  <.live_file_input upload={@uploads.image} class="sr-only" />
                  <label for={@uploads.image.ref} class="cursor-pointer flex flex-col items-center gap-2">
                    <.icon name="hero-photo" class="size-10 text-base-content/30" />
                    <span class="text-sm text-base-content/60">
                      Drop image here or <span class="text-primary font-semibold">browse</span>
                    </span>
                    <span class="text-xs text-base-content/40">JPG, PNG, GIF, WebP · max 5 MB</span>
                  </label>
                </div>

                <div :for={entry <- @uploads.image.entries} class="mt-3 flex items-start gap-3 p-3 bg-base-200 rounded-xl">
                  <div class="relative shrink-0">
                    <.live_img_preview entry={entry} class="size-20 rounded-lg object-cover border border-base-300" />
                    <button
                      type="button"
                      phx-click="cancel_upload"
                      phx-value-ref={entry.ref}
                      class="absolute -top-2 -right-2 btn btn-circle btn-xs btn-error"
                    >
                      <.icon name="hero-x-mark" class="size-3" />
                    </button>
                  </div>
                  <div class="flex-1 min-w-0">
                    <p class="text-sm font-medium truncate">{entry.client_name}</p>
                    <div class="w-full bg-base-300 rounded-full h-1.5 mt-2">
                      <div
                        class="bg-primary h-1.5 rounded-full transition-all duration-300"
                        style={"width: #{entry.progress}%"}
                      >
                      </div>
                    </div>
                    <p class="text-xs text-base-content/50 mt-1">{entry.progress}%</p>
                    <p :for={err <- upload_errors(@uploads.image, entry)} class="text-error text-xs mt-1">
                      {error_to_string(err)}
                    </p>
                  </div>
                </div>

                <div
                  :if={@thread.image_url && @uploads.image.entries == []}
                  class="mt-3 flex items-center gap-3 p-3 bg-base-200 rounded-xl"
                >
                  <img src={@thread.image_url} class="size-20 rounded-lg object-cover border border-base-300 shrink-0" />
                  <div>
                    <p class="text-sm font-medium text-base-content">Current cover image</p>
                    <p class="text-xs text-base-content/50 mt-0.5">Upload a new image to replace it</p>
                  </div>
                </div>

                <p :for={err <- upload_errors(@uploads.image)} class="text-error text-xs mt-1">
                  {error_to_string(err)}
                </p>
              </div>

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
    socket =
      socket
      |> allow_upload(:image,
        accept: ~w(.jpg .jpeg .png .gif .webp),
        max_entries: 1,
        max_file_size: 5_000_000
      )
      |> assign(:return_to, return_to(params["return_to"]))
      |> apply_action(socket.assigns.live_action, params)

    {:ok, socket}
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

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :image, ref)}
  end

  def handle_event("save", %{"thread" => thread_params}, socket) do
    save_thread(socket, socket.assigns.live_action, thread_params)
  end

  defp save_thread(socket, :edit, thread_params) do
    case consume_image(socket) do
      {:error, :unsafe_content} ->
        {:noreply, put_flash(socket, :error, "Gambar mengandung konten yang tidak sesuai dan tidak dapat diunggah.")}

      {:error, {:upload_failed, _reason}} ->
        {:noreply, put_flash(socket, :error, "Gagal mengunggah gambar. Periksa konfigurasi penyimpanan.")}

      image_result ->
        {image_url, image_warning} =
          case image_result do
            {:ok, data} -> data
            nil -> {socket.assigns.thread.image_url, socket.assigns.thread.image_warning}
          end

        params =
          thread_params
          |> Map.put("image_url", image_url)
          |> Map.put("image_warning", image_warning)

        case Forum.update_thread(socket.assigns.current_scope, socket.assigns.thread, params) do
          {:ok, thread} ->
            {:noreply,
             socket
             |> put_flash(:info, "Thread updated successfully")
             |> push_navigate(to: return_path(socket.assigns.current_scope, socket.assigns.return_to, thread))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end
    end
  end

  defp save_thread(socket, :new, thread_params) do
    case consume_image(socket) do
      {:error, :unsafe_content} ->
        {:noreply, put_flash(socket, :error, "Gambar mengandung konten yang tidak sesuai dan tidak dapat diunggah.")}

      {:error, {:upload_failed, _reason}} ->
        {:noreply, put_flash(socket, :error, "Gagal mengunggah gambar. Periksa konfigurasi penyimpanan.")}

      image_result ->
        {image_url, image_warning} =
          case image_result do
            {:ok, data} -> data
            nil -> {nil, nil}
          end

        params =
          thread_params
          |> Map.put("image_url", image_url)
          |> Map.put("image_warning", image_warning)

        case Forum.create_thread(socket.assigns.current_scope, params) do
          {:ok, thread} ->
            {:noreply,
             socket
             |> put_flash(:info, "Thread created successfully")
             |> push_navigate(to: return_path(socket.assigns.current_scope, socket.assigns.return_to, thread))}

          {:error, %Ecto.Changeset{} = changeset} ->
            {:noreply, assign(socket, form: to_form(changeset))}
        end
    end
  end

  defp consume_image(socket) do
    results =
      consume_uploaded_entries(socket, :image, fn %{path: path}, entry ->
        binary = File.read!(path)

        case Rekognition.safe?(binary) do
          :ok ->
            {:ok, warning} = Rekognition.detect_animal_warning(binary)

            case Uploads.upload_thread_image(path, entry.client_name) do
              {:ok, url} -> {:ok, {:ok, {url, warning}}}
              {:error, reason} -> {:ok, {:error, {:upload_failed, reason}}}
            end

          {:error, :unsafe_content} ->
            {:ok, {:error, :unsafe_content}}
        end
      end)

    List.first(results)
  end

  defp error_to_string(:too_large), do: "File too large (max 5 MB)"
  defp error_to_string(:not_accepted), do: "Unsupported file type"
  defp error_to_string(:too_many_files), do: "Only 1 image allowed"
  defp error_to_string(err), do: "Upload error: #{inspect(err)}"

  defp return_path(_scope, "index", _thread), do: ~p"/threads"
  defp return_path(_scope, "show", thread), do: ~p"/threads/#{thread}"
end
