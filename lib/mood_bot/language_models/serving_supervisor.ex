defmodule MoodBot.LanguageModels.ServingSupervisor do
  @moduledoc """
  DynamicSupervisor specifically for managing Nx.Serving processes.

  This supervisor is optimized for starting and stopping Nx.Serving processes
  on demand, following proper DynamicSupervisor patterns.
  """

  use DynamicSupervisor
  require Logger

  @doc """
  Starts the serving processes supervisor.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @doc """
  Starts an Nx.Serving process under supervision.

  Returns `{:ok, pid}` if successful, `{:error, reason}` otherwise.
  """
  @spec start_serving(any(), keyword()) :: DynamicSupervisor.on_start_child()
  def start_serving(serving, opts \\ []) do
    name =
      Keyword.get(opts, :name, :"#{__MODULE__}.Serving.#{System.unique_integer([:positive])}")

    child_spec = {Nx.Serving, serving: serving, name: name}

    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, pid} = result ->
        Logger.info("Started Nx.Serving process", pid: pid, name: name)
        result

      {:error, reason} = error ->
        Logger.error("Failed to start Nx.Serving process", error: reason)
        error
    end
  end

  @doc """
  Stops an Nx.Serving process.

  Returns `:ok` if successful, `{:error, reason}` otherwise.
  """
  @spec stop_serving(pid()) :: :ok | {:error, any()}
  def stop_serving(pid) when is_pid(pid) do
    case DynamicSupervisor.terminate_child(__MODULE__, pid) do
      :ok ->
        Logger.info("Stopped Nx.Serving process", pid: pid)
        :ok

      {:error, reason} = error ->
        Logger.error("Failed to stop Nx.Serving process", pid: pid, error: reason)
        error
    end
  end

  @doc """
  Lists all currently running children.
  """
  @spec which_children() :: [{:undefined, pid(), :worker | :supervisor, [module()]}]
  def which_children do
    DynamicSupervisor.which_children(__MODULE__)
  end

  @doc """
  Counts the number of running children.
  """
  @spec count_children() :: map()
  def count_children do
    DynamicSupervisor.count_children(__MODULE__)
  end

  # DynamicSupervisor callbacks

  @impl true
  def init(_init_arg) do
    Logger.info("Starting ServingSupervisor for Nx.Serving processes")

    # Proper DynamicSupervisor usage - no children started in init/1
    # Children will be started on demand via start_child/2
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end