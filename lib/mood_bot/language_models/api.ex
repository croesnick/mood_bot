defmodule MoodBot.LanguageModels.Api do
  @moduledoc """
  GenServer that manages language model serving processes.

  Supervises Nx.Serving processes to protect expensive model compilation
  from crashes and provides graceful error handling for model loading.
  """

  use GenServer
  require Logger

  @typedoc "Current status of the model"
  @type status :: :unloaded | :loading | :loaded | :error

  @typedoc "Model configuration"
  @type model_config :: [
          repo: {:hf, String.t()} | {:hf, String.t(), keyword()},
          generation_config: keyword()
        ]

  @typedoc "GenServer state"
  @type state :: %{
          name: atom(),
          serving_name: atom() | nil,
          model_config: model_config(),
          status: status(),
          error_reason: any()
        }

  # Client API

  @doc """
  Starts the language model GenServer.

  ## Options

  - `:model_config` - Model configuration map
  - `:name` - Process name (required)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) do
    model_config = Keyword.fetch!(opts, :model_config)
    name = Keyword.fetch!(opts, :name)

    GenServer.start_link(__MODULE__, {name, model_config}, name: name)
  end

  @doc """
  Loads the language model and starts the serving process.

  Returns `:ok` if loading is successful, or `{:error, reason}` if it fails.
  """
  @spec load_model(atom()) :: :ok | {:error, any()}
  def load_model(name) do
    GenServer.call(name, :load_model, :infinity)
  end

  @doc """
  Unloads the current model by stopping the serving process.
  """
  @spec unload_model(atom()) :: :ok
  def unload_model(name) do
    GenServer.call(name, :unload_model)
  end

  @doc """
  Generates text based on the given prompt asynchronously, calling the provided callback function
  with each text chunk as it's generated.

  The callback function is executed within a Task process linked to the caller,
  providing non-blocking generation while maintaining proper supervision.

  Returns `{:ok, task_pid}` if generation starts successfully,
  or `{:error, reason}` if the model is not loaded or task creation fails.

  ## Examples

      # Stream to IO asynchronously
      {:ok, task} = MoodBot.LanguageModels.Api.generate(:smollm_1_7b, "Tell me about Elixir", &IO.write/1)

  """
  @spec generate(atom(), String.t(), (String.t() -> any())) :: {:ok, pid()} | {:error, any()}
  def generate(name, prompt, callback) when is_function(callback, 1) do
    case GenServer.call(name, :status) do
      :loaded ->
        GenServer.cast(name, {:generate, prompt, callback, self()})

        receive do
          {:generation_started, task_pid} -> {:ok, task_pid}
          {:generation_error, reason} -> {:error, reason}
        after
          5000 -> {:error, :task_start_timeout}
        end

      status ->
        {:error, {:model_not_loaded, status}}
    end
  end

  @doc """
  Returns the current status of the model.
  """
  @spec status(atom()) :: status()
  def status(name) do
    GenServer.call(name, :status)
  end

  # GenServer callbacks

  @impl true
  def init({name, model_config}) do
    Logger.info("Initializing MoodBot.LanguageModels.Api GenServer", name: name)
    Logger.info("Received model_config", name: name, model_config: model_config)

    state = %{
      name: name,
      serving_name: nil,
      model_config: model_config,
      status: :unloaded,
      error_reason: nil
    }

    Logger.info("Language model GenServer started successfully",
      name: name,
      model_config: model_config,
      initial_state: state
    )

    {:ok, state}
  end

  @impl true
  def handle_call(:load_model, _from, %{status: :loading} = state) do
    {:reply, {:error, :already_loading}, state}
  end

  def handle_call(:load_model, _from, %{status: :loaded} = state) do
    {:reply, :ok, state}
  end

  def handle_call(:load_model, _from, state) do
    Logger.info("Starting model loading process")

    new_state = %{state | status: :loading, error_reason: nil}

    with {:ok, loaded_state} <- do_load_model(new_state) do
      Logger.info("Model loaded successfully")
      {:reply, :ok, loaded_state}
    else
      {:error, reason} ->
        Logger.error("Model loading failed", error: reason)
        error_state = %{new_state | status: :error, error_reason: reason}
        {:reply, {:error, reason}, error_state}
    end
  end

  @impl true
  def handle_call(:unload_model, _from, state) do
    {:ok, new_state} = do_unload_model(state)
    Logger.info("Model unloaded successfully")
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_cast({:generate, prompt, callback, caller_pid}, %{status: :loaded} = state) do
    case do_generate(prompt, callback, caller_pid, state) do
      {:ok, task_pid} ->
        send(caller_pid, {:generation_started, task_pid})
        {:noreply, state}

      {:error, reason} ->
        send(caller_pid, {:generation_error, reason})
        {:noreply, state}
    end
  end

  def handle_cast({:generate, _prompt, _callback, caller_pid}, %{status: status} = state) do
    send(caller_pid, {:generation_error, {:model_not_loaded, status}})
    {:noreply, state}
  end

  @impl true
  def handle_call(:status, _from, %{status: status} = state) do
    {:reply, status, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.debug("Unexpected message received", message: msg)
    {:noreply, state}
  end

  # Private functions

  @spec do_load_model(state()) :: {:ok, state()} | {:error, any()}
  defp do_load_model(%{model_config: config} = state) do
    Logger.info("Loading language model", config: config)
    start_time = System.monotonic_time(:millisecond)

    with {:ok, model_info} <- load_bumblebee_model(config),
         {:ok, tokenizer} <- load_bumblebee_tokenizer(config),
         {:ok, generation_config} <- load_bumblebee_generation_config(config),
         {:ok, serving} <- create_serving(model_info, tokenizer, generation_config, config),
         {:ok, serving_name} <- start_serving_child(serving, state.name) do
      end_time = System.monotonic_time(:millisecond)
      loading_duration = end_time - start_time

      Logger.info("Language model loading completed successfully",
        duration_ms: loading_duration,
        serving_name: serving_name
      )

      new_state = %{state | serving_name: serving_name, status: :loaded}

      {:ok, new_state}
    else
      {:error, reason} = error ->
        end_time = System.monotonic_time(:millisecond)
        loading_duration = end_time - start_time

        Logger.error("Model loading failed",
          error: reason,
          duration_ms: loading_duration,
          config: config
        )

        error
    end
  end

  @spec do_unload_model(state()) :: {:ok, state()} | {:error, any()}
  defp do_unload_model(%{serving_name: nil} = state) do
    {:ok, %{state | status: :unloaded}}
  end

  defp do_unload_model(%{serving_name: serving_name} = state) when is_atom(serving_name) do
    # For now, let the supervisor manage serving lifecycle
    # We could add a stop_serving_by_name function if needed
    Logger.info("Unloading model by clearing serving name", serving_name: serving_name)

    new_state = %{state | serving_name: nil, status: :unloaded}
    {:ok, new_state}
  end

  @spec load_bumblebee_model(model_config()) :: {:ok, any()} | {:error, any()}
  defp load_bumblebee_model(config) do
    repo = Keyword.fetch!(config, :repo)
    Logger.info("Loading Bumblebee model", repo: repo)
    start_time = System.monotonic_time(:millisecond)

    case Bumblebee.load_model(repo, type: :bf16) do
      {:ok, model_info} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time
        Logger.info("Bumblebee model loaded successfully", duration_ms: duration, repo: repo)
        {:ok, model_info}

      {:error, reason} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        Logger.error("Bumblebee model loading failed",
          error: reason,
          duration_ms: duration,
          repo: repo
        )

        {:error, {:model_load_failed, reason}}
    end
  end

  @spec load_bumblebee_tokenizer(model_config()) :: {:ok, any()} | {:error, any()}
  defp load_bumblebee_tokenizer(config) do
    repo = Keyword.fetch!(config, :repo)
    Logger.info("Loading Bumblebee tokenizer", repo: repo)
    start_time = System.monotonic_time(:millisecond)

    case Bumblebee.load_tokenizer(repo) do
      {:ok, tokenizer} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time
        Logger.info("Bumblebee tokenizer loaded successfully", duration_ms: duration, repo: repo)
        {:ok, tokenizer}

      {:error, reason} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        Logger.error("Bumblebee tokenizer loading failed",
          error: reason,
          duration_ms: duration,
          repo: repo
        )

        {:error, {:tokenizer_load_failed, reason}}
    end
  end

  @spec load_bumblebee_generation_config(model_config()) :: {:ok, any()} | {:error, any()}
  defp load_bumblebee_generation_config(config) do
    repo = Keyword.fetch!(config, :repo)
    gen_config = Keyword.fetch!(config, :generation_config)
    Logger.info("Loading Bumblebee generation config", repo: repo, gen_config: gen_config)
    start_time = System.monotonic_time(:millisecond)

    with {:ok, base_config} <- Bumblebee.load_generation_config(repo) do
      configured = Bumblebee.configure(base_config, gen_config)
      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      Logger.info("Bumblebee generation config loaded successfully",
        duration_ms: duration,
        repo: repo
      )

      {:ok, configured}
    else
      {:error, reason} ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        Logger.error("Bumblebee generation config loading failed",
          error: reason,
          duration_ms: duration,
          repo: repo,
          gen_config: gen_config
        )

        {:error, {:generation_config_load_failed, reason}}
    end
  end

  @spec create_serving(any(), any(), any(), model_config()) :: {:ok, any()} | {:error, any()}
  defp create_serving(model_info, tokenizer, generation_config, config) do
    Logger.info("Creating Bumblebee Text.generation serving")

    Logger.info("EXLA backend status",
      backend: Nx.default_backend(),
      exla_available: Code.ensure_loaded(EXLA)
    )

    start_time = System.monotonic_time(:millisecond)

    try do
      serving =
        Bumblebee.Text.generation(model_info, tokenizer, generation_config,
          compile: [batch_size: 1, sequence_length: 1028],
          stream: true
          # defn_options: [compiler: EXLA]
        )

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time
      Logger.info("Bumblebee serving created successfully", duration_ms: duration)
      {:ok, serving}
    rescue
      error ->
        end_time = System.monotonic_time(:millisecond)
        duration = end_time - start_time

        Logger.error("Bumblebee serving creation failed",
          error: error,
          duration_ms: duration,
          backend: Nx.default_backend()
        )

        {:error, {:serving_creation_failed, error}}
    end
  end

  @spec start_serving_child(any(), atom()) :: {:ok, atom()} | {:error, any()}
  defp start_serving_child(serving, api_name) do
    serving_name = :"#{api_name}.Serving.#{System.unique_integer([:positive])}"
    Logger.info("Starting serving child process", api_name: api_name, serving_name: serving_name)

    case MoodBot.LanguageModels.ServingSupervisor.start_serving(serving, name: serving_name) do
      {:ok, _pid} ->
        Logger.info("Serving child started successfully",
          api_name: api_name,
          serving_name: serving_name
        )

        {:ok, serving_name}

      {:error, reason} ->
        Logger.error("Serving child start failed",
          error: reason,
          api_name: api_name,
          serving_name: serving_name
        )

        {:error, {:serving_start_failed, reason}}
    end
  end

  @spec do_generate(String.t(), (String.t() -> any()), pid(), state()) ::
          {:ok, pid()} | {:error, any()}
  defp do_generate(prompt, callback, _caller_pid, %{serving_name: serving_name})
       when is_atom(serving_name) do
    try do
      # Start a Task linked to the caller for async stream processing
      task_pid =
        Task.start_link(fn ->
          try do
            Nx.Serving.batched_run(serving_name, prompt)
            |> Enum.each(callback)
          rescue
            error ->
              Logger.error("Generation task failed", error: error, serving_name: serving_name)
              # Task will exit with error, linked caller will receive EXIT signal
              exit({:generation_failed, error})
          catch
            :exit, reason ->
              Logger.error("Generation task caught exit",
                reason: reason,
                serving_name: serving_name
              )

              exit({:serving_exit, reason})
          end
        end)

      case task_pid do
        {:ok, pid} -> {:ok, pid}
        {:error, reason} -> {:error, {:task_start_failed, reason}}
      end
    rescue
      error -> {:error, {:task_creation_failed, error}}
    end
  end
end
