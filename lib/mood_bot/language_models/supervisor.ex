defmodule MoodBot.LanguageModels.Supervisor do
  @moduledoc """
  Main supervisor for the language model subsystem.

  Manages:
  - MoodBot.LanguageModels.ServingSupervisor (dynamic supervisor for Nx.Serving processes)
  - MoodBot.LanguageModels.Api GenServers (one per configured model)
  """

  use Supervisor
  require Logger

  @doc """
  Starts the language models supervisor.
  """
  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  # Supervisor callbacks

  @impl true
  def init(init_arg) do
    Logger.info("Starting LanguageModels.Supervisor", init_arg: init_arg)

    models_config = Keyword.fetch!(init_arg, :models_config)
    Logger.debug("Extracted models_config for API GenServers", models_config: models_config)

    # Define static children
    children = [
      # Start the dynamic supervisor for Nx.Serving processes first
      {MoodBot.LanguageModels.ServingSupervisor, []}

      # Start API GenServers as static children (one per model config)
    ] ++ Enum.map(models_config, fn {name, config} ->
      {MoodBot.LanguageModels.Api, name: name, model_config: config}
    end)

    Logger.info("Starting Language Model children", count: length(children))

    # Use regular Supervisor.init with static children
    Supervisor.init(children, strategy: :one_for_one)
  end
end
