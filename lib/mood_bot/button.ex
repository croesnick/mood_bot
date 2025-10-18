defmodule MoodBot.Button do
  @moduledoc """
  GPIO button input handler for MoodBot.

  Monitors a physical button connected to GPIO 27 (Physical Pin 13) and triggers
  the Controller when pressed. Includes software debouncing to filter mechanical bounce.

  ## Hardware Setup

  - Button connected between GPIO 27 (Pin 13) and GND (Pin 9)
  - Internal pull-up resistor enabled (no external resistor needed)
  - Falling edge detection (button press pulls GPIO low)
  """

  use GenServer
  require Logger

  @type button_state :: %{
          gpio_ref: reference() | nil,
          debounce_ms: non_neg_integer(),
          debounce_timer_ref: reference() | nil
        }

  ## Client API

  @doc """
  Starts the Button GenServer.

  Options are loaded from application config.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Button: Initializing GPIO button handler")

    config = Application.get_env(:mood_bot, __MODULE__, [])
    gpio_pin = Keyword.fetch!(config, :gpio_pin)
    debounce_ms = Keyword.fetch!(config, :debounce_ms)

    case initialize_gpio(gpio_pin) do
      {:ok, gpio_ref} ->
        Logger.info("Button: GPIO initialized successfully on pin #{inspect(gpio_pin)}")

        state = %{
          gpio_ref: gpio_ref,
          debounce_ms: debounce_ms,
          debounce_timer_ref: nil
        }

        {:ok, state}

      {:error, reason} ->
        Logger.error("Button: Failed to initialize GPIO", error: reason, pin: gpio_pin)
        # Fail fast - supervisor can decide restart strategy
        {:stop, {:gpio_init_failed, reason}}
    end
  end

  ## GPIO Functions

  @spec initialize_gpio({String.t(), non_neg_integer()}) ::
          {:ok, reference()} | {:error, any()}
  defp initialize_gpio({chip, pin}) do
    with {:ok, gpio_ref} <- Circuits.GPIO.open(chip, pin, :input),
         :ok <- Circuits.GPIO.set_pull_mode(gpio_ref, :pullup),
         :ok <- Circuits.GPIO.set_interrupts(gpio_ref, :falling) do
      {:ok, gpio_ref}
    end
  end

  ## Interrupt Handling

  @impl true
  def handle_info({:circuits_gpio, _pin, _timestamp, 0}, %{debounce_timer_ref: nil} = state) do
    # Falling edge detected - no active debounce, process it
    Logger.debug("Button: GPIO interrupt - falling edge detected")
    Logger.debug("Button: Starting debounce timer (#{state.debounce_ms}ms)")

    timer_ref = Process.send_after(self(), :debounce_complete, state.debounce_ms)
    {:noreply, %{state | debounce_timer_ref: timer_ref}}
  end

  def handle_info({:circuits_gpio, _pin, _timestamp, 0}, state) do
    # Falling edge detected but debounce timer active - ignore (bouncing)
    Logger.debug("Button: GPIO interrupt - ignoring bounce (debounce active)")
    {:noreply, state}
  end

  def handle_info({:circuits_gpio, _pin, _timestamp, _value}, state) do
    # Ignore rising edge (button released)
    {:noreply, state}
  end

  @impl true
  def handle_info(:debounce_complete, state) do
    Logger.info("Button: Debounce complete - processing button press")

    # Call Controller to handle the button press
    case MoodBot.Controller.handle_button_press() do
      :ok ->
        Logger.debug("Button: Controller accepted button press")

      {:error, reason} ->
        Logger.warning("Button: Controller rejected button press", error: reason)
    end

    # Clear debounce timer
    {:noreply, %{state | debounce_timer_ref: nil}}
  end
end
