defmodule MoodBot.Display do
  @moduledoc """
  GenServer for managing the Waveshare 2.9" e-ink display with reliable state management.

  This module provides a high-level API for the Waveshare 2.9" V2 e-ink display,
  implementing a robust state machine that manages hardware initialization, display
  refresh cycles, power management, and error recovery. The implementation follows
  the Python reference driver specifications from Waveshare.

  ## Features

  - **State Machine Management**: Tracks display states (idle, updating, refreshing, power saving)
  - **Automatic Refresh Cycles**: Performs full refresh every 3 minutes to prevent ghosting
  - **Power Management**: Enters sleep mode after 5 minutes of inactivity
  - **Partial Update Limiting**: Forces full refresh after 5 partial updates
  - **Hardware Abstraction**: Uses HAL pattern for development (MockHAL) and hardware (RpiHAL)
  - **Error Recovery**: Graceful handling of hardware timeouts and communication failures

  ## State Machine

  The display operates in four primary states:

  - `:idle_and_ready` - Ready for operations, can accept new commands
  - `:updating_display` - Currently performing a display update (partial or full)
  - `:refreshing_screen` - Performing automatic full refresh cycle
  - `:power_saving` - In sleep mode to conserve power

  ## Configuration

  GPIO pin configuration is loaded from `config/target.exs`:

      config :mood_bot, MoodBot.Display,
        spi_device: "spidev0.0",
        dc_gpio: {"gpiochip0", 25},
        rst_gpio: {"gpiochip0", 17},
        busy_gpio: {"gpiochip0", 24},
        pwr_gpio: {"gpiochip0", 18}

  ## Usage Example

      # Start the display GenServer
      {:ok, _pid} = MoodBot.Display.start_link()

      # Initialize hardware
      :ok = MoodBot.Display.init_display()

      # Display content
      :ok = MoodBot.Display.show_mood(:happy)
      :ok = MoodBot.Display.clear()

      # Check status
      status = MoodBot.Display.status()

  ## Reference Implementation

  This implementation follows the Waveshare Python driver specifications:
  - [Waveshare EPD 2.9" V2 Driver](https://github.com/waveshareteam/e-Paper/blob/master/RaspberryPi_JetsonNano/python/lib/waveshare_epd/epd2in9_V2.py)
  - Hardware initialization and command sequences match the reference driver
  - Timing constants and refresh cycles follow documented specifications
  """

  use GenServer
  require Logger

  alias MoodBot.Display.Driver

  @typedoc """
  Display refresh state machine states.

  - `:idle_and_ready` - Ready for operations
  - `:updating_display` - Performing display update
  - `:refreshing_screen` - Automatic refresh cycle
  - `:power_saving` - Sleep mode active
  """
  @type refresh_state :: :idle_and_ready | :updating_display | :refreshing_screen | :power_saving

  @typedoc """
  Display operational state.

  - `:stopped` - GenServer starting up
  - `:ready` - HAL initialized, ready for display init
  - `:initialized` - Display hardware initialized and ready
  - `:sleeping` - Display in sleep mode
  - `:error` - Error state requiring intervention
  """
  @type display_state :: :stopped | :ready | :initialized | :sleeping | :error

  @typedoc """
  Supported mood indicators for simple display patterns.
  """
  @type mood :: :happy | :sad | :neutral | :angry | :surprised

  @typedoc """
  Specific error atoms returned by display operations.
  """
  @type error ::
          :not_initialized | :invalid_state | :timeout | :invalid_mood | :invalid_image_size

  @typedoc """
  Display status information returned by status/1.
  """
  @type status_info :: %{
          initialized: boolean(),
          display_state: display_state(),
          refresh_state: refresh_state(),
          last_refresh_time: integer() | nil,
          last_activity_time: integer() | nil,
          partial_update_count: non_neg_integer(),
          refresh_timer_active: boolean(),
          power_save_timer_active: boolean(),
          ms_since_last_refresh: integer() | nil,
          ms_since_last_activity: integer() | nil,
          next_refresh_in_ms: integer() | nil,
          next_power_save_in_ms: integer() | nil
        }

  # Timing constants from documentation
  # 3 minutes
  @refresh_interval_ms 3 * 60 * 1000
  # 5 minutes
  @power_save_interval_ms 5 * 60 * 1000
  # Arbitrary limit to prevent excessive partial updates
  @max_partial_updates_before_full_refresh 5

  defstruct [
    :driver_state,
    :display_state,
    # TODO Rename to `active?`
    initialized?: false,
    # State machine tracking
    refresh_state: :idle_and_ready,
    last_refresh_time: nil,
    last_activity_time: nil,
    partial_update_count: 0,
    # Timer references
    refresh_timer_ref: nil,
    power_save_timer_ref: nil
  ]

  ## Client API

  @doc """
  Start the Display GenServer with required configuration.

  Initializes the GenServer and HAL layer but does not initialize the display hardware.
  Call `init_display/1` after startup to initialize the e-ink display.

  ## Required Configuration

  The following configuration must be provided in `config/target.exs`:

      config :mood_bot, MoodBot.Display,
        spi_device: "spidev0.0",
        dc_gpio: {"gpiochip0", 25},
        rst_gpio: {"gpiochip0", 17},
        busy_gpio: {"gpiochip0", 24},
        pwr_gpio: {"gpiochip0", 18}

  ## Options
  - `:config` - Hardware configuration map (optional, overrides application config)
  - `:name` - GenServer name (defaults to `#{__MODULE__}`)

  ## Examples

      # Start with application configuration from config/target.exs
      {:ok, pid} = MoodBot.Display.start_link()

      # Start with custom name
      {:ok, pid} = MoodBot.Display.start_link(name: :my_display)

      # Start with custom configuration (overrides application config)
      config = %{
        spi_device: "spidev0.1",
        dc_gpio: {"gpiochip0", 20},
        rst_gpio: {"gpiochip0", 17},
        busy_gpio: {"gpiochip0", 24},
        pwr_gpio: {"gpiochip0", 18}
      }
      {:ok, pid} = MoodBot.Display.start_link(config: config)

  ## Returns
  - `{:ok, pid}` - Successfully started GenServer
  - `{:error, {:invalid_config, reason}}` - Required configuration missing or invalid
  - `{:error, {:hal_init_failed, reason}}` - HAL initialization failed
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    {name, opts} = Keyword.pop(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Initialize the display hardware following the Waveshare Python driver sequence.

  Performs the complete hardware initialization sequence including:
  - Hardware reset with precise timing (50ms-2ms-50ms)
  - Software reset and driver configuration
  - Memory area and pointer setup
  - LUT (Look-Up Table) loading for refresh timing
  - State transition to `:idle_and_ready`

  This function must be called after `start_link/1` and before any display operations.
  Initialization typically takes 2-5 seconds and includes waiting for the display
  to become ready via the BUSY pin.

  ## Parameters
  - `server` - GenServer name/pid (defaults to `#{__MODULE__}`)

  ## Examples

      # Initialize with default server
      :ok = MoodBot.Display.init_display()

      # Initialize specific server instance
      :ok = MoodBot.Display.init_display(:my_display)

  ## Returns
  - `:ok` - Display successfully initialized and ready for operations
  - `{:error, :not_initialized}` - HAL not properly initialized
  - `{:error, :invalid_state}` - Display not in correct state for initialization
  - `{:error, reason}` - Hardware initialization failed (GPIO/SPI error)

  ## Reference
  Based on [Waveshare EPD 2.9" V2 initialization](https://github.com/waveshareteam/e-Paper/blob/master/RaspberryPi_JetsonNano/python/lib/waveshare_epd/epd2in9_V2.py#L144)
  """
  @spec init_display(GenServer.server()) :: :ok | {:error, :invalid_state | :timeout | term()}
  def init_display(server \\ __MODULE__) do
    GenServer.call(server, :init_display, 30_000)
  end

  @doc """
  Clear the display to white using full refresh.

  Fills the entire display with white pixels and performs a full refresh cycle
  to ensure clean output. This operation resets the partial update counter
  and helps prevent ghosting artifacts.

  ## Parameters
  - `server` - GenServer name/pid (defaults to `#{__MODULE__}`)

  ## Examples

      :ok = MoodBot.Display.clear()

  ## Returns
  - `:ok` - Display cleared successfully
  - `{:error, :not_initialized}` - Display hardware not initialized
  - `{:error, :invalid_state}` - Display not in correct state for operation
  - `{:error, reason}` - Hardware operation failed

  ## Timing
  Full refresh operation takes approximately 15-20 seconds to complete.
  """
  @spec clear(GenServer.server()) :: :ok | {:error, :not_initialized | :invalid_state | term()}
  def clear(server \\ __MODULE__) do
    GenServer.call(server, :clear, 30_000)
  end

  @doc """
  Display raw image data with automatic refresh strategy.

  Displays binary image data using either partial update (fast, ~2-3 seconds)
  or full refresh (slow, ~15-20 seconds) based on timing and update count.
  The system automatically chooses full refresh when:
  - More than 3 minutes since last full refresh
  - 5 or more partial updates have occurred
  - Display was in power saving mode

  ## Parameters
  - `server` - GenServer name/pid (defaults to `#{__MODULE__}`)
  - `image_data` - Binary data with 1 bit per pixel (0=black, 1=white)

  ## Image Format
  - **Size**: Exactly 4736 bytes (128 × 296 ÷ 8)
  - **Format**: 1 bit per pixel, packed into bytes
  - **Bit order**: MSB first within each byte
  - **Color mapping**: 0 = black pixel, 1 = white pixel

  ## Examples

      # Display image from file
      image_data = File.read!("image.bin")
      :ok = MoodBot.Display.display_image(image_data)

  ## Returns
  - `:ok` - Image displayed successfully
  - `{:error, :not_initialized}` - Display hardware not initialized
  - `{:error, :invalid_state}` - Display not in correct state for operation
  - `{:error, :invalid_image_size}` - Image data is wrong size
  - `{:error, reason}` - Hardware operation failed
  """
  @spec display_image(GenServer.server(), binary()) ::
          :ok | {:error, :not_initialized | :invalid_state | :invalid_image_size | term()}
  def display_image(server \\ __MODULE__, image_data) when is_binary(image_data) do
    GenServer.call(server, {:display_image, image_data}, 30_000)
  end

  @doc """
  Display a simple mood indicator with predefined patterns.

  Shows one of several built-in mood patterns using automatic refresh strategy.
  Each mood displays a unique pattern designed to be visually distinctive:
  - `:happy` - Alternating checkerboard pattern (0x55/0xAA)
  - `:sad` - Vertical lines pattern (0x0F repeating)
  - `:neutral` - Horizontal lines pattern (alternating rows)
  - `:angry` - Diagonal pattern (every 3rd byte black)
  - `:surprised` - Border pattern (frame with 4-pixel border)

  ## Parameters
  - `server` - GenServer name/pid (defaults to `#{__MODULE__}`)
  - `mood` - Mood type to display

  ## Examples

      # Display happy mood
      :ok = MoodBot.Display.show_mood(:happy)

      # Display on specific server
      :ok = MoodBot.Display.show_mood(:my_display, :surprised)

  ## Returns
  - `:ok` - Mood displayed successfully
  - `{:error, :not_initialized}` - Display hardware not initialized
  - `{:error, :invalid_state}` - Display not in correct state for operation
  - `{:error, :invalid_mood}` - Invalid mood type provided
  - `{:error, reason}` - Hardware operation failed
  """
  @spec show_mood(GenServer.server(), mood()) ::
          :ok | {:error, :not_initialized | :invalid_state | :invalid_mood | term()}
  def show_mood(server \\ __MODULE__, mood)
      when mood in [:happy, :sad, :neutral, :angry, :surprised] do
    GenServer.call(server, {:show_mood, mood}, 30_000)
  end

  @doc """
  Put the display into deep sleep mode following Python driver sequence.

  Sends the deep sleep command (0x10) with activation data (0x01) and performs
  proper shutdown sequence. In sleep mode, the display consumes minimal power
  and retains the last displayed image. The display can be woken by calling
  any display operation.

  ## Parameters
  - `server` - GenServer name/pid (defaults to `#{__MODULE__}`)

  ## Examples

      # Put display to sleep
      :ok = MoodBot.Display.sleep()

  ## Returns
  - `:ok` - Display entered sleep mode successfully
  - `{:error, reason}` - Failed to enter sleep mode

  ## Reference
  Based on [Waveshare EPD sleep sequence](https://github.com/waveshareteam/e-Paper/blob/master/RaspberryPi_JetsonNano/python/lib/waveshare_epd/epd2in9_V2.py#L520)
  """
  @spec sleep(GenServer.server()) :: :ok | {:error, term()}
  def sleep(server \\ __MODULE__) do
    GenServer.call(server, :sleep, 30_000)
  end

  @spec status() :: %{
          display_state: :error | :initialized | :ready | :sleeping | :stopped,
          initialized: boolean(),
          last_activity_time: nil | integer(),
          last_refresh_time: nil | integer(),
          ms_since_last_activity: nil | integer(),
          ms_since_last_refresh: nil | integer(),
          next_power_save_in_ms: nil | integer(),
          next_refresh_in_ms: nil | integer(),
          partial_update_count: non_neg_integer(),
          power_save_timer_active: boolean(),
          refresh_state: :idle_and_ready | :power_saving | :refreshing_screen | :updating_display,
          refresh_timer_active: boolean()
        }
  @doc """
  Get comprehensive display status information.

  Returns detailed information about the display's current state, timing,
  and operational status. Useful for debugging and monitoring display health.

  ## Parameters
  - `server` - GenServer name/pid (defaults to `#{__MODULE__}`)

  ## Examples

      status = MoodBot.Display.status()
      IO.puts("Display initialized: \#{status.initialized}")
      IO.puts("State: \#{status.display_state}")
      IO.puts("Refresh state: \#{status.refresh_state}")
  """
  @spec status(GenServer.server()) :: status_info()
  def status(server \\ __MODULE__) do
    GenServer.call(server, :status)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Display: Starting")

    now = System.monotonic_time(:millisecond)

    state = %__MODULE__{
      driver_state: nil,
      display_state: :stopped,
      last_activity_time: now,
      refresh_state: :idle_and_ready
    }

    new_state = schedule_power_save_timer(state)

    Logger.info("Display: GenServer started successfully")
    {:ok, new_state}
  end

  @impl true
  def handle_call(:init_display, _from, %{initialized?: true} = state) do
    Logger.debug("Display: Already initialized")
    {:reply, :ok, state}
  end

  def handle_call(:init_display, _from, %{initialized?: false} = state) do
    Logger.info("Display: Initializing hardware")

    case validate_refresh_state(state) do
      :ok ->
        case Driver.init() do
          {:ok, driver_state} ->
            now = System.monotonic_time(:millisecond)

            new_state =
              %{
                state
                | driver_state: driver_state,
                  initialized?: true,
                  display_state: :initialized,
                  last_refresh_time: now
              }
              |> transition_to_state(:idle_and_ready)
              |> update_activity_time()
              |> schedule_refresh_timer()

            Logger.info("Display: Hardware initialization complete")
            {:reply, :ok, new_state}

          {:error, reason} ->
            Logger.error("Display: Hardware initialization failed",
              error: reason,
              display_state: state.display_state,
              initialized: state.initialized?
            )

            new_state = %{state | display_state: :error}
            {:reply, {:error, {:init_failed, reason}}, new_state}
        end

      {:error, reason} ->
        Logger.error("Display: Invalid state for initialization",
          error: reason,
          current_state: state.refresh_state,
          display_state: state.display_state,
          initialized: state.initialized?
        )

        {:reply, {:error, :invalid_state}, state}
    end
  end

  def handle_call(:clear, _from, state) do
    Logger.info("Display: Clearing display")

    {width, height} = Driver.dimensions()
    color = 0xFF
    image_data = :binary.copy(<<color>>, div(width * height, 8))

    with {:ok, state} <- validate_initialization(state),
         {:ok, state} <- validate_refresh_state_monadic(state),
         {:ok, state} <- ensure_display_is_active(state),
         {:ok, state} <- perform_clear_operation(state, image_data) do
      {:reply, :ok, state}
    else
      {:error, reason} ->
        Logger.error("Display: Clear operation failed", error: reason)
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:display_image, image_data}, _from, state) when is_binary(image_data) do
    Logger.info("Display: Displaying image (#{byte_size(image_data)} bytes)")

    with {:ok, state} <- validate_initialization(state),
         {:ok, state} <- validate_refresh_state_monadic(state),
         {:ok, state} <- ensure_display_is_active(state),
         {:ok, state} <- perform_display_operation(state, image_data, "image display") do
      {:reply, :ok, state}
    else
      {:error, reason} ->
        Logger.error("Display: Image display operation failed", error: reason)
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:show_mood, mood}, _from, state)
      when mood in [:happy, :sad, :neutral, :angry, :surprised] do
    Logger.info("Display: Showing mood: #{mood}")

    # Generate simple mood indicator
    image_data = generate_mood_image(mood)

    with {:ok, state} <- validate_initialization(state),
         {:ok, state} <- validate_refresh_state_monadic(state),
         {:ok, state} <- ensure_display_is_active(state),
         {:ok, state} <- perform_display_operation(state, image_data, "#{mood} mood") do
      {:reply, :ok, state}
    else
      {:error, reason} ->
        Logger.error("Display: Mood display operation failed", error: reason, mood: mood)
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:show_mood, invalid_mood}, _from, state) do
    Logger.error("Display: Invalid mood: #{inspect(invalid_mood)}")
    {:reply, {:error, :invalid_mood}, state}
  end

  def handle_call(:sleep, _from, state) do
    Logger.info("Display: Entering hibernate mode (user requested)")

    case Driver.hibernate(state.driver_state) do
      {:ok, driver_state} ->
        new_state =
          state
          |> transition_to_state(:power_saving)
          |> Map.put(:driver_state, driver_state)
          |> Map.put(:display_state, :sleeping)

        Logger.info("Display: Sleep mode entered successfully")
        {:reply, :ok, new_state}

      {:error, reason} ->
        Logger.error("Display: Sleep failed: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:status, _from, state) do
    now = System.monotonic_time(:millisecond)

    status = %{
      initialized: state.initialized?,
      display_state: state.display_state,
      refresh_state: state.refresh_state,
      # Timing information
      last_refresh_time: state.last_refresh_time,
      last_activity_time: state.last_activity_time,
      partial_update_count: state.partial_update_count,
      # Timer status
      refresh_timer_active: state.refresh_timer_ref != nil,
      power_save_timer_active: state.power_save_timer_ref != nil,
      # Time since last events
      ms_since_last_refresh:
        if(state.last_refresh_time, do: now - state.last_refresh_time, else: nil),
      ms_since_last_activity:
        if(state.last_activity_time, do: now - state.last_activity_time, else: nil),
      # Next scheduled events
      next_refresh_in_ms:
        if(state.refresh_timer_ref,
          do: @refresh_interval_ms - (now - (state.last_refresh_time || now)),
          else: nil
        ),
      next_power_save_in_ms:
        if(state.power_save_timer_ref,
          do: @power_save_interval_ms - (now - (state.last_activity_time || now)),
          else: nil
        )
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info(:auto_refresh, state) do
    Logger.info("Display: Performing automatic full refresh (3-minute cycle)")

    # Perform full refresh by clearing the display with full refresh
    # Create white image data for full refresh
    {width, height} = Driver.dimensions()
    image_size = div(width, 8) * height
    white_data = :binary.copy(<<0xFF>>, image_size)

    state = transition_to_state(state, :refreshing_screen)

    case Driver.render_image(state.driver_state, white_data) do
      {:ok, driver_state} ->
        updated_state =
          state
          |> perform_full_refresh_update(driver_state)
          |> Map.put(:refresh_timer_ref, nil)

        {:noreply, updated_state}

      {:error, reason} ->
        Logger.error("Display: Auto refresh failed",
          error: reason,
          operation: :auto_refresh,
          refresh_state: state.refresh_state,
          partial_count: state.partial_update_count,
          last_refresh_ms_ago:
            if(state.last_refresh_time,
              do: System.monotonic_time(:millisecond) - state.last_refresh_time,
              else: nil
            )
        )

        new_state =
          state
          |> transition_to_state(:idle_and_ready)
          |> Map.put(:refresh_timer_ref, nil)

        {:noreply, new_state}
    end
  end

  def handle_info(:power_save, state) do
    Logger.info("Display: Entering power save mode (5-minute timeout)")

    state = transition_to_state(state, :power_saving)

    case Driver.hibernate(state.driver_state) do
      {:ok, driver_state} ->
        updated_state =
          state
          |> Map.put(:driver_state, driver_state)
          |> Map.put(:power_save_timer_ref, nil)

        {:noreply, updated_state}

      {:error, reason} ->
        Logger.error("Display: Power save failed",
          error: reason,
          operation: :power_save,
          refresh_state: state.refresh_state,
          time_since_last_activity:
            if(state.last_activity_time,
              do: System.monotonic_time(:millisecond) - state.last_activity_time,
              else: nil
            )
        )

        new_state =
          state
          |> transition_to_state(:idle_and_ready)
          |> Map.put(:power_save_timer_ref, nil)

        {:noreply, new_state}
    end
  end

  @impl true
  def terminate(reason, state) do
    Logger.info("Display: Terminating (#{inspect(reason)})")

    # Cancel any active timers
    if state.refresh_timer_ref do
      Process.cancel_timer(state.refresh_timer_ref)
    end

    if state.power_save_timer_ref do
      Process.cancel_timer(state.power_save_timer_ref)
    end

    if state.driver_state do
      %{hal_module: hal, hal_state: hal_state} = state.driver_state
      hal.close(hal_state)
    end

    :ok
  end

  ## Private Functions

  # Configuration validation
  defp validate_config(config) do
    required_keys = [:spi_device, :dc_gpio, :rst_gpio, :busy_gpio, :pwr_gpio]
    missing_keys = Enum.filter(required_keys, &(not Map.has_key?(config, &1)))

    if Enum.empty?(missing_keys) do
      :ok
    else
      {:error, {:missing_required_config, missing_keys}}
    end
  end

  # State transition functions
  defp transition_to_state(state, new_refresh_state) do
    case validate_state_transition(state.refresh_state, new_refresh_state) do
      :ok ->
        Logger.debug("Display: State transition #{state.refresh_state} -> #{new_refresh_state}")
        %{state | refresh_state: new_refresh_state}

      {:error, reason} ->
        Logger.error(
          "Display: Invalid state transition #{state.refresh_state} -> #{new_refresh_state}: #{reason}"
        )

        state
    end
  end

  defp ensure_display_is_active(state) do
    case state.refresh_state do
      :power_saving ->
        Logger.info("Display: Waking up from power saving mode")

        case Driver.init() do
          {:ok, driver_state} ->
            now = System.monotonic_time(:millisecond)

            new_state =
              state
              |> Map.put(:driver_state, driver_state)
              |> Map.put(:initialized?, true)
              |> Map.put(:display_state, :initialized)
              |> Map.put(:last_refresh_time, now)
              |> transition_to_state(:idle_and_ready)

            {:ok, new_state}

          {:error, reason} ->
            Logger.error("Display: Failed to wake from power saving mode", error: reason)

            error_state =
              state
              |> Map.put(:display_state, :error)
              |> Map.put(:initialized?, false)

            {:error, error_state}
        end

      _ ->
        {:ok, state}
    end
  end

  defp perform_full_refresh_update(state, driver_state) do
    now = System.monotonic_time(:millisecond)

    state
    |> transition_to_state(:idle_and_ready)
    |> Map.put(:driver_state, driver_state)
    |> Map.put(:last_refresh_time, now)
    |> Map.put(:partial_update_count, 0)
    |> schedule_refresh_timer()
    |> update_activity_time()
  end

  defp perform_partial_refresh_update(state, driver_state) do
    state
    |> transition_to_state(:idle_and_ready)
    |> Map.put(:driver_state, driver_state)
    |> Map.put(:partial_update_count, state.partial_update_count + 1)
    |> update_activity_time()
  end

  # State validation functions
  defp validate_state_transition(same_state, same_state), do: :ok

  defp validate_state_transition(from_state, to_state) do
    valid_transitions = %{
      :idle_and_ready => [:updating_display, :refreshing_screen, :power_saving],
      :updating_display => [:idle_and_ready],
      :refreshing_screen => [:idle_and_ready],
      :power_saving => [:idle_and_ready, :updating_display]
    }

    case Map.get(valid_transitions, from_state, []) do
      valid_states when is_list(valid_states) ->
        if to_state in valid_states do
          :ok
        else
          {:error, "#{to_state} is not a valid transition from #{from_state}"}
        end

      _ ->
        {:error, "Unknown state #{from_state}"}
    end
  end

  defp validate_refresh_state(state) do
    valid_states = [:idle_and_ready, :updating_display, :refreshing_screen, :power_saving]

    if state.refresh_state in valid_states do
      :ok
    else
      {:error, "Invalid refresh state: #{state.refresh_state}"}
    end
  end

  # Monadic validation helpers
  defp validate_initialization(state) do
    if state.initialized? do
      {:ok, state}
    else
      {:error, :not_initialized}
    end
  end

  defp validate_refresh_state_monadic(state) do
    case validate_refresh_state(state) do
      :ok -> {:ok, state}
      {:error, _reason} -> {:error, :invalid_state}
    end
  end

  # Operation helper functions
  defp perform_clear_operation(state, data) do
    state = transition_to_state(state, :updating_display)

    case Driver.clear(state.driver_state, data) do
      {:ok, driver_state} ->
        new_state = perform_full_refresh_update(state, driver_state)
        Logger.info("Display: Clear complete - full refresh performed")
        {:ok, new_state}

      {:error, reason} ->
        Logger.error("Display: Clear failed",
          error: reason,
          operation: :clear,
          refresh_state: state.refresh_state,
          partial_count: state.partial_update_count
        )

        {:error, {:clear_failed, reason}}
    end
  end

  defp perform_display_operation(state, image_data, operation_name) do
    needs_full = needs_full_refresh?(state)

    Logger.info(
      "Display: Using #{if needs_full, do: "full refresh", else: "partial update"}
                 (#{state.partial_update_count} partials since last full,
                  #{if state.last_refresh_time, do: "#{System.monotonic_time(:millisecond) - state.last_refresh_time}ms", else: "never"} since last refresh)"
    )

    state = transition_to_state(state, :updating_display)

    operation_result =
      if needs_full do
        Driver.render_image(state.driver_state, image_data)
      else
        Driver.render_image_partial(state.driver_state, image_data)
      end

    case operation_result do
      {:ok, driver_state} ->
        new_state =
          if needs_full do
            Logger.info("Display: Full refresh complete for #{operation_name}")
            perform_full_refresh_update(state, driver_state)
          else
            Logger.info("Display: Partial update complete for #{operation_name}")
            perform_partial_refresh_update(state, driver_state)
          end

        {:ok, new_state}

      {:error, reason} ->
        Logger.error("Display: #{operation_name} failed",
          error: reason,
          refresh_type: if(needs_full, do: :full_refresh, else: :partial_update),
          refresh_state: state.refresh_state,
          partial_count: state.partial_update_count
        )

        {:error, {:operation_failed, reason}}
    end
  end

  # Timer management functions
  defp schedule_refresh_timer(state) do
    # Cancel existing timer if present
    if state.refresh_timer_ref do
      Process.cancel_timer(state.refresh_timer_ref)
    end

    timer_ref = Process.send_after(self(), :auto_refresh, @refresh_interval_ms)
    %{state | refresh_timer_ref: timer_ref}
  end

  defp schedule_power_save_timer(state) do
    # Cancel existing timer if present
    if state.power_save_timer_ref do
      Process.cancel_timer(state.power_save_timer_ref)
    end

    timer_ref = Process.send_after(self(), :power_save, @power_save_interval_ms)
    %{state | power_save_timer_ref: timer_ref}
  end

  defp update_activity_time(state) do
    now = System.monotonic_time(:millisecond)

    %{state | last_activity_time: now}
    |> schedule_power_save_timer()
  end

  defp needs_full_refresh?(state) do
    now = System.monotonic_time(:millisecond)

    cond do
      # No previous refresh recorded
      state.last_refresh_time == nil -> true
      # More than 3 minutes since last refresh
      now - state.last_refresh_time > @refresh_interval_ms -> true
      # Too many partial updates
      state.partial_update_count >= @max_partial_updates_before_full_refresh -> true
      # Default to partial update
      true -> false
    end
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
