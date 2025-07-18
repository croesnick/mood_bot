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

  # Timing constants from documentation
  # 3 minutes
  @refresh_interval_ms 3 * 60 * 1000
  # 5 minutes
  @power_save_interval_ms 5 * 60 * 1000
  # Arbitrary limit to prevent excessive partial updates
  @max_partial_updates_before_full_refresh 5

  if Mix.target() != :host do
    alias MoodBot.Display.RpiHAL
  end

  @default_config %{
    # Hardware configuration for Raspberry Pi
    spi_device: "spidev0.0",
    # Data/Command pin
    dc_pin: 22,
    # Reset pin
    rst_pin: 11,
    # Busy signal pin
    busy_pin: 18,
    # Chip Select pin
    cs_pin: 24,
    # Will be set based on target
    hal_module: nil
  }

  defstruct [
    :hal_module,
    :hal_state,
    :config,
    :display_state,
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

    now = System.monotonic_time(:millisecond)

    state = %__MODULE__{
      config: config,
      hal_module: config.hal_module,
      display_state: :stopped,
      last_activity_time: now,
      refresh_state: :idle_and_ready
    }

    # Initialize HAL
    case state.hal_module.init(config) do
      {:ok, hal_state} ->
        new_state =
          %{state | hal_state: hal_state, display_state: :ready}
          |> schedule_power_save_timer()

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

  def handle_call(:init_display, _from, %{initialized?: false} = state) do
    Logger.info("Display: Initializing hardware")

    case validate_refresh_state(state) do
      :ok ->
        case Driver.init(state.hal_module, state.hal_state) do
          {:ok, hal_state} ->
            now = System.monotonic_time(:millisecond)

            new_state =
              %{
                state
                | hal_state: hal_state,
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
            Logger.error("Display: Hardware initialization failed: #{inspect(reason)}")
            new_state = %{state | display_state: :error}
            {:reply, {:error, reason}, new_state}
        end

      {:error, reason} ->
        Logger.error("Display: Invalid state for initialization: #{reason}")
        {:reply, {:error, :invalid_state}, state}
    end
  end

  def handle_call(:clear, _from, %{initialized?: false} = state) do
    {:reply, {:error, :not_initialized}, state}
  end

  def handle_call(:clear, _from, %{initialized?: true} = state) do
    Logger.info("Display: Clearing display")

    case validate_refresh_state(state) do
      :ok ->
        # Clear always uses full refresh
        {width, height} = Driver.dimensions()
        image_size = div(width, 8) * height
        white_data = :binary.copy(<<0xFF>>, image_size)

        # Force wake from power saving and use full refresh
        state = wake_from_power_saving(state)
        state = transition_to_state(state, :updating_display)

        case MoodBot.Display.Driver.display_frame_full(
               state.hal_module,
               state.hal_state,
               white_data
             ) do
          {:ok, hal_state} ->
            new_state = perform_full_refresh_update(state, hal_state)
            Logger.info("Display: Clear complete - full refresh performed")
            {:reply, :ok, new_state}

          {:error, reason} = _error ->
            Logger.error("Display: Clear failed: #{inspect(reason)}")
            new_state = transition_to_state(state, :idle_and_ready)
            {:reply, {:error, reason}, new_state}
        end

      {:error, reason} ->
        Logger.error("Display: Invalid state for clear: #{reason}")
        {:reply, {:error, :invalid_state}, state}
    end
  end

  def handle_call({:display_image, _image_data}, _from, %{initialized?: false} = state) do
    {:reply, {:error, :not_initialized}, state}
  end

  def handle_call({:display_image, image_data}, _from, %{initialized?: true} = state)
      when is_binary(image_data) do
    Logger.info("Display: Displaying image (#{byte_size(image_data)} bytes)")

    case validate_refresh_state(state) do
      :ok ->
        operation_fn = fn needs_full ->
          if needs_full do
            MoodBot.Display.Driver.display_frame_full(
              state.hal_module,
              state.hal_state,
              image_data
            )
          else
            MoodBot.Display.Driver.display_frame_partial(
              state.hal_module,
              state.hal_state,
              image_data
            )
          end
        end

        case handle_display_operation(state, operation_fn) do
          {:ok, new_state} ->
            {:reply, :ok, new_state}

          {:error, new_state, reason} ->
            {:reply, {:error, reason}, new_state}
        end

      {:error, reason} ->
        Logger.error("Display: Invalid state for image display: #{reason}")
        {:reply, {:error, :invalid_state}, state}
    end
  end

  def handle_call({:show_mood, _mood}, _from, %{initialized?: false} = state) do
    {:reply, {:error, :not_initialized}, state}
  end

  def handle_call({:show_mood, mood}, _from, %{initialized?: true} = state)
      when mood in [:happy, :sad, :neutral, :angry, :surprised] do
    Logger.info("Display: Showing mood: #{mood}")

    case validate_refresh_state(state) do
      :ok ->
        # Generate simple mood indicator
        image_data = generate_mood_image(mood)

        operation_fn = fn needs_full ->
          result =
            if needs_full do
              MoodBot.Display.Driver.display_frame_full(
                state.hal_module,
                state.hal_state,
                image_data
              )
            else
              MoodBot.Display.Driver.display_frame_partial(
                state.hal_module,
                state.hal_state,
                image_data
              )
            end

          case result do
            {:ok, hal_state} ->
              Logger.info(
                "Display: #{if needs_full, do: "Full refresh", else: "Partial update"} complete for #{mood} mood"
              )

              {:ok, hal_state}

            error ->
              error
          end
        end

        case handle_display_operation(state, operation_fn) do
          {:ok, new_state} ->
            {:reply, :ok, new_state}

          {:error, new_state, reason} ->
            {:reply, {:error, reason}, new_state}
        end

      {:error, reason} ->
        Logger.error("Display: Invalid state for mood display: #{reason}")
        {:reply, {:error, :invalid_state}, state}
    end
  end

  def handle_call({:show_mood, invalid_mood}, _from, %{initialized?: true} = state) do
    Logger.error("Display: Invalid mood: #{inspect(invalid_mood)}")
    {:reply, {:error, :invalid_mood}, state}
  end

  def handle_call(:sleep, _from, state) do
    Logger.info("Display: Entering sleep mode (manual)")

    case Driver.sleep(state.hal_module, state.hal_state) do
      {:ok, hal_state} ->
        new_state =
          state
          |> transition_to_state(:power_saving)
          |> Map.put(:hal_state, hal_state)
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
      hal_module: state.hal_module,
      config: Map.drop(state.config, [:hal_module]),
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

    case MoodBot.Display.Driver.display_frame_full(state.hal_module, state.hal_state, white_data) do
      {:ok, hal_state} ->
        updated_state =
          state
          |> perform_full_refresh_update(hal_state)
          |> Map.put(:refresh_timer_ref, nil)

        {:noreply, updated_state}

      {:error, reason} ->
        Logger.error("Display: Auto refresh failed: #{inspect(reason)}")

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

    # Put display to sleep
    case Driver.sleep(state.hal_module, state.hal_state) do
      {:ok, hal_state} ->
        updated_state =
          state
          |> Map.put(:hal_state, hal_state)
          |> Map.put(:power_save_timer_ref, nil)

        {:noreply, updated_state}

      {:error, reason} ->
        Logger.error("Display: Power save failed: #{inspect(reason)}")

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

    if state.hal_state do
      state.hal_module.close(state.hal_state)
    end

    :ok
  end

  ## Private Functions

  defp ensure_map(config) when is_map(config), do: config
  defp ensure_map(config) when is_list(config), do: Enum.into(config, %{})
  defp ensure_map(_), do: %{}

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

  defp wake_from_power_saving(state) do
    case state.refresh_state do
      :power_saving ->
        Logger.info("Display: Waking up from power saving mode")
        transition_to_state(state, :idle_and_ready)

      _ ->
        state
    end
  end

  defp perform_full_refresh_update(state, hal_state) do
    now = System.monotonic_time(:millisecond)

    state
    |> transition_to_state(:idle_and_ready)
    |> Map.put(:hal_state, hal_state)
    |> Map.put(:last_refresh_time, now)
    |> Map.put(:partial_update_count, 0)
    |> schedule_refresh_timer()
    |> update_activity_time()
  end

  defp perform_partial_refresh_update(state, hal_state) do
    state
    |> transition_to_state(:idle_and_ready)
    |> Map.put(:hal_state, hal_state)
    |> Map.put(:partial_update_count, state.partial_update_count + 1)
    |> update_activity_time()
  end

  defp handle_display_operation(state, operation_fn) do
    # Common pattern for display operations
    state = wake_from_power_saving(state)
    needs_full = needs_full_refresh?(state)

    Logger.info(
      "Display: Using #{if needs_full, do: "full refresh", else: "partial update"} 
                 (#{state.partial_update_count} partials since last full, 
                  #{if state.last_refresh_time, do: "#{System.monotonic_time(:millisecond) - state.last_refresh_time}ms", else: "never"} since last refresh)"
    )

    # Set updating state
    state = transition_to_state(state, :updating_display)

    case operation_fn.(needs_full) do
      {:ok, hal_state} ->
        new_state =
          if needs_full do
            Logger.info("Display: Full refresh complete")
            perform_full_refresh_update(state, hal_state)
          else
            Logger.info("Display: Partial update complete")
            perform_partial_refresh_update(state, hal_state)
          end

        {:ok, new_state}

      {:error, reason} ->
        Logger.error("Display: Operation failed: #{inspect(reason)}")
        new_state = transition_to_state(state, :idle_and_ready)
        {:error, new_state, reason}
    end
  end

  # State validation functions
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
