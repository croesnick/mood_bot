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

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MoodBot.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # List all child processes to be supervised
  if Mix.target() == :host do
    defp target_children do
      [
        # Children that only run on the host during development or test.
        # In general, prefer using `config/host.exs` for differences.
        #
        # Start display with mock HAL for development
        {MoodBot.Display, []}
      ]
    end
  else
    defp target_children do
      [
        # Children for all targets except host
        # Start display with real hardware HAL
        {MoodBot.Display, []}
      ]
    end
  end
end
