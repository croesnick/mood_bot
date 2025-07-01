defmodule MoodBot.Display do
  @moduledoc """
  GenServer for managing the Waveshare 2.9" e-ink display.

  This module provides a high-level API for the e-ink display,
  managing hardware state and providing functions for displaying
  content, mood indicators, and basic graphics.
  """

  use GenServer
  require Logger

  alias MoodBot.Display.{Driver, MockHAL}

  if Mix.target() != :host do
    alias MoodBot.Display.RpiHAL
  end

  @default_config %{
    # Hardware configuration for Raspberry Pi
    spi_device: "spidev0.0",
    # Data/Command pin
    dc_pin: 25,
    # Reset pin
    rst_pin: 17,
    # Busy signal pin
    busy_pin: 24,
    # Chip Select pin
    cs_pin: 8,
    # Will be set based on target
    hal_module: nil
  }

  defstruct [
    :hal_module,
    :hal_state,
    :config,
    :display_state,
    initialized?: false
  ]

  ## Client API

  @doc """
  Start the Display GenServer.

  ## Options
  - `:config` - Hardware configuration map (optional)
  - `:name` - GenServer name (defaults to __MODULE__)
  """
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Initialize the display hardware.
  """
  def init_display(server \\ __MODULE__) do
    GenServer.call(server, :init_display, 30_000)
  end

  @doc """
  Clear the display to white.
  """
  def clear(server \\ __MODULE__) do
    GenServer.call(server, :clear, 30_000)
  end

  @doc """
  Display raw image data.

  Image data should be binary with 1 bit per pixel, where 0 = black, 1 = white.
  Expected size: (width / 8) * height bytes.
  """
  def display_image(server \\ __MODULE__, image_data) when is_binary(image_data) do
    GenServer.call(server, {:display_image, image_data}, 30_000)
  end

  @doc """
  Display a simple mood indicator.

  Moods: :happy, :sad, :neutral, :angry, :surprised
  """
  def show_mood(server \\ __MODULE__, mood)
      when mood in [:happy, :sad, :neutral, :angry, :surprised] do
    GenServer.call(server, {:show_mood, mood}, 30_000)
  end

  @doc """
  Put the display into sleep mode.
  """
  def sleep(server \\ __MODULE__) do
    GenServer.call(server, :sleep, 30_000)
  end

  @doc """
  Get display status information.
  """
  def status(server \\ __MODULE__) do
    GenServer.call(server, :status)
  end

  ## GenServer Callbacks

  @impl true
  def init(opts) do
    # Merge default config with application config and any passed options
    app_config =
      :mood_bot
      |> Application.get_env(__MODULE__, %{})
      |> ensure_map()

    config =
      @default_config
      |> Map.merge(app_config)
      |> Map.merge(Keyword.get(opts, :config, %{}))
      |> set_hal_module()

    Logger.info("Display: Starting with config: #{inspect(config)}")

    state = %__MODULE__{
      config: config,
      hal_module: config.hal_module,
      display_state: :stopped
    }

    # Initialize HAL
    case state.hal_module.init(config) do
      {:ok, hal_state} ->
        new_state = %{state | hal_state: hal_state, display_state: :ready}
        Logger.info("Display: GenServer started successfully")
        {:ok, new_state}

      {:error, reason} = error ->
        Logger.error("Display: Failed to initialize HAL: #{inspect(reason)}")
        {:stop, {:hal_init_failed, error}}
    end
  end

  @impl true
  def handle_call(:init_display, _from, %{initialized?: true} = state) do
    Logger.debug("Display: Already initialized")
    {:reply, :ok, state}
  end

  def handle_call(:init_display, _from, state) do
    Logger.info("Display: Initializing hardware")

    case Driver.init(state.hal_module, state.hal_state) do
      {:ok, hal_state} ->
        new_state = %{
          state
          | hal_state: hal_state,
            initialized?: true,
            display_state: :initialized
        }

        Logger.info("Display: Hardware initialization complete")
        {:reply, :ok, new_state}

      {:error, reason} = error ->
        Logger.error("Display: Hardware initialization failed: #{inspect(reason)}")
        new_state = %{state | display_state: :error}
        {:reply, error, new_state}
    end
  end

  def handle_call(:clear, _from, %{initialized?: false} = state) do
    {:reply, {:error, :not_initialized}, state}
  end

  def handle_call(:clear, _from, state) do
    Logger.info("Display: Clearing display")

    case Driver.clear(state.hal_module, state.hal_state) do
      {:ok, hal_state} ->
        new_state = %{state | hal_state: hal_state}
        {:reply, :ok, new_state}

      {:error, reason} = error ->
        Logger.error("Display: Clear failed: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  def handle_call({:display_image, _image_data}, _from, %{initialized?: false} = state) do
    {:reply, {:error, :not_initialized}, state}
  end

  def handle_call({:display_image, image_data}, _from, state) do
    Logger.info("Display: Displaying image (#{byte_size(image_data)} bytes)")

    case Driver.display_frame(state.hal_module, state.hal_state, image_data) do
      {:ok, hal_state} ->
        new_state = %{state | hal_state: hal_state}
        {:reply, :ok, new_state}

      {:error, reason} = error ->
        Logger.error("Display: Image display failed: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  def handle_call({:show_mood, _mood}, _from, %{initialized?: false} = state) do
    {:reply, {:error, :not_initialized}, state}
  end

  def handle_call({:show_mood, mood}, _from, state) do
    Logger.info("Display: Showing mood: #{mood}")

    # Generate simple mood indicator
    image_data = generate_mood_image(mood)

    case Driver.display_frame(state.hal_module, state.hal_state, image_data) do
      {:ok, hal_state} ->
        new_state = %{state | hal_state: hal_state}
        {:reply, :ok, new_state}

      {:error, reason} = error ->
        Logger.error("Display: Mood display failed: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  def handle_call(:sleep, _from, state) do
    Logger.info("Display: Entering sleep mode")

    case Driver.sleep(state.hal_module, state.hal_state) do
      {:ok, hal_state} ->
        new_state = %{state | hal_state: hal_state, display_state: :sleeping}
        {:reply, :ok, new_state}

      {:error, reason} = error ->
        Logger.error("Display: Sleep failed: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  def handle_call(:status, _from, state) do
    status = %{
      initialized: state.initialized?,
      display_state: state.display_state,
      hal_module: state.hal_module,
      config: Map.drop(state.config, [:hal_module])
    }

    {:reply, status, state}
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Display: Terminating (#{inspect(reason)})")

    if state.hal_state do
      state.hal_module.close(state.hal_state)
    end

    :ok
  end

  ## Private Functions

  defp ensure_map(config) when is_map(config), do: config
  defp ensure_map(config) when is_list(config), do: Enum.into(config, %{})
  defp ensure_map(_), do: %{}

  if Mix.target() == :host do
    defp set_hal_module(%{hal_module: nil} = config) do
      Map.put(config, :hal_module, MockHAL)
    end

    defp set_hal_module(config), do: config
  else
    defp set_hal_module(%{hal_module: nil} = config) do
      Map.put(config, :hal_module, RpiHAL)
    end

    defp set_hal_module(config), do: config
  end

  defp generate_mood_image(mood) do
    {width, height} = Driver.dimensions()
    image_size = div(width, 8) * height

    # For now, generate simple patterns based on mood
    case mood do
      :happy ->
        # Alternating pattern for happy
        generate_happy_pattern(image_size)

      :sad ->
        # Vertical lines for sad
        generate_pattern_image(image_size, fn _i -> 0x0F end)

      :neutral ->
        # Horizontal lines for neutral
        generate_neutral_pattern(image_size, width)

      :angry ->
        # Diagonal pattern for angry
        generate_angry_pattern(image_size)

      :surprised ->
        # Border pattern for surprised
        generate_border_image(width, height)
    end
  end

  defp generate_pattern_image(size, pattern_fn) do
    0..(size - 1)
    |> Enum.map(pattern_fn)
    |> :binary.list_to_bin()
  end

  defp generate_neutral_pattern(image_size, width) do
    bytes_per_row = div(width, 8)

    pattern_fn = fn i ->
      row_position = rem(div(i, bytes_per_row), 4)
      if row_position < 2, do: 0x00, else: 0xFF
    end

    generate_pattern_image(image_size, pattern_fn)
  end

  defp generate_happy_pattern(image_size) do
    generate_pattern_image(image_size, fn i ->
      if rem(i, 2) == 0, do: 0x55, else: 0xAA
    end)
  end

  defp generate_angry_pattern(image_size) do
    generate_pattern_image(image_size, fn i ->
      if rem(i, 3) == 0, do: 0x00, else: 0xFF
    end)
  end

  defp generate_border_image(width, height) do
    bytes_per_row = div(width, 8)

    for y <- 0..(height - 1) do
      if y < 4 or y >= height - 4 do
        # Top or bottom border - all black
        :binary.copy(<<0x00>>, bytes_per_row)
      else
        # Middle rows with side borders
        # Left 4 pixels black
        left_border = <<0x0F>>
        # Middle white
        middle = :binary.copy(<<0xFF>>, bytes_per_row - 2)
        # Right 4 pixels black
        right_border = <<0xF0>>
        <<left_border::binary, middle::binary, right_border::binary>>
      end
    end
    |> IO.iodata_to_binary()
  end
end
