defmodule MoodBot.LED do
  @moduledoc """
  Simple LED control for demo mode feedback.

  Manages a GPIO output pin to control an LED indicator.
  """

  use GenServer
  require Logger

  ## Client API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec on() :: :ok
  def on do
    GenServer.call(__MODULE__, :on)
  end

  @spec off() :: :ok
  def off do
    GenServer.call(__MODULE__, :off)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("LED: Initializing")

    # Get LED pin from Button config (shares same config)
    config = Application.get_env(:mood_bot, MoodBot.Button, [])
    led_pin = Keyword.fetch!(config, :led_pin)

    case Circuits.GPIO.open(led_pin, :output) do
      {:ok, gpio_ref} ->
        # Start with LED off
        Circuits.GPIO.write(gpio_ref, 0)
        Logger.info("LED: Ready on pin #{inspect(led_pin)}")
        {:ok, %{gpio_ref: gpio_ref}}

      {:error, reason} ->
        Logger.error("LED: Failed to initialize", error: reason)
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:on, _from, state) do
    Circuits.GPIO.write(state.gpio_ref, 1)
    Logger.debug("LED: ON")
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:off, _from, state) do
    Circuits.GPIO.write(state.gpio_ref, 0)
    Logger.debug("LED: OFF")
    {:reply, :ok, state}
  end

  @impl true
  def terminate(_reason, state) do
    Circuits.GPIO.close(state.gpio_ref)
  end
end
