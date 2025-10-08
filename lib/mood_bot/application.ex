defmodule MoodBot.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        # Children for all targets
        # Starts a worker by calling: MoodBot.Worker.start_link(arg)
        # {MoodBot.Worker, arg},
      ] ++ target_children()

    # Try to auto-configure WiFi from environment variables on target devices
    if runtime_target() != :host do
      MoodBot.WiFiConfig.auto_configure()
    end

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MoodBot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Runtime-safe target detection
  defp runtime_target do
    case Code.ensure_loaded(VintageNet) do
      {:module, VintageNet} -> :target
      {:error, _} -> :host
    end
  end

  # List all child processes to be supervised
  if Mix.target() == :host do
    defp target_children do
      [
        # Children that only run on the host during development or test.
        # In general, prefer using `config/host.exs` for differences.
        #
        # Start display with mock HAL for development
        {MoodBot.Display, []},
        # Start network monitor (will be inactive on host)
        # {MoodBot.NetworkMonitor, []},
        # Start language model subsystem
        {MoodBot.LanguageModels.Supervisor,
         models_config: Application.get_env(:mood_bot, :language_models, [])},
        # Start German sentiment analysis
        {MoodBot.SentimentAnalysis, []},
        # Start Whisper serving for speech-to-text
        {MoodBot.STT.Whisper, []},
        # Start STT manager for recording coordination
        {MoodBot.STT.Manager, []},
        # Start main controller
        {MoodBot.Controller, []}
      ]
    end
  else
    defp target_children do
      [
        # Children for all targets except host
        # Start display with real hardware HAL
        {MoodBot.Display, []},
        # Start network monitor for real-time network status tracking
        # {MoodBot.NetworkMonitor, []},
        # Start language model subsystem
        {MoodBot.LanguageModels.Supervisor,
         models_config: Application.get_env(:mood_bot, :language_models, [])},
        # Start German sentiment analysis
        {MoodBot.SentimentAnalysis, []},
        # Start Whisper serving for speech-to-text
        {MoodBot.STT.Whisper, []},
        # Start STT manager for recording coordination
        {MoodBot.STT.Manager, []},
        # Start main controller
        {MoodBot.Controller, []}
      ]
    end
  end
end
