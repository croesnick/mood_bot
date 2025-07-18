defmodule MoodBot.Display.Driver do
  @moduledoc """
  Low-level driver for Waveshare 2.9" e-ink display (epd2in9b_V4).

  This module implements the command sequences and protocols needed
  to communicate with the display hardware. It translates the Python
  library commands to Elixir/Nerves compatible code.
  """

  require Logger

  # Display specifications
  @width 128
  @height 296

  # Commands for Waveshare 2.9" V4 display
  @commands %{
    # Basic commands
    driver_output_control: 0x01,
    booster_soft_start_control: 0x0C,
    gate_scan_start_position: 0x0F,
    deep_sleep_mode: 0x10,
    data_entry_mode: 0x11,
    sw_reset: 0x12,
    temperature_sensor_control: 0x1A,
    master_activation: 0x20,
    display_update_control_1: 0x21,
    display_update_control_2: 0x22,
    write_ram: 0x24,
    write_vcom_register: 0x2C,
    write_lut_register: 0x32,
    set_dummy_line_period: 0x3A,
    set_gate_time: 0x3B,
    border_waveform_control: 0x3C,
    set_ram_x_address_start_end_position: 0x44,
    set_ram_y_address_start_end_position: 0x45,
    set_ram_x_address_counter: 0x4E,
    set_ram_y_address_counter: 0x4F,
    terminate_frame_read_write: 0xFF
  }

  @doc """
  Get display dimensions.
  """
  def dimensions, do: {@width, @height}

  @doc """
  Send a command to the display.
  """
  def send_command(hal, hal_state, command) when is_integer(command) do
    with {:ok, hal_state} <- hal.gpio_set_dc(hal_state, 0),
         {:ok, hal_state} <- hal.spi_write(hal_state, <<command>>) do
      {:ok, hal_state}
    end
  end

  @doc """
  Send data to the display.
  """
  def send_data(hal, hal_state, data) when is_binary(data) do
    with {:ok, hal_state} <- hal.gpio_set_dc(hal_state, 1),
         {:ok, hal_state} <- hal.spi_write(hal_state, data) do
      {:ok, hal_state}
    end
  end

  @doc """
  Hardware reset sequence.
  """
  def reset(hal, hal_state) do
    Logger.debug("Display: Hardware reset")

    with {:ok, hal_state} <- hal.gpio_set_rst(hal_state, 1),
         :ok <- hal.sleep(200),
         {:ok, hal_state} <- hal.gpio_set_rst(hal_state, 0),
         :ok <- hal.sleep(2),
         {:ok, hal_state} <- hal.gpio_set_rst(hal_state, 1),
         :ok <- hal.sleep(200) do
      {:ok, hal_state}
    end
  end

  @doc """
  Wait for the display to become ready (busy pin low).
  """
  def wait_until_idle(hal, hal_state, timeout_ms \\ 10_000) do
    Logger.debug("Display: Waiting until idle")
    wait_until_idle_loop(hal, hal_state, timeout_ms, System.monotonic_time(:millisecond))
  end

  defp wait_until_idle_loop(hal, hal_state, timeout_ms, start_time) do
    current_time = System.monotonic_time(:millisecond)

    if current_time - start_time > timeout_ms do
      Logger.error("Display: Timeout waiting for idle state")
      {:error, :timeout}
    else
      case hal.gpio_read_busy(hal_state) do
        {:ok, 0, hal_state} ->
          Logger.debug("Display: Ready (idle)")
          {:ok, hal_state}

        {:ok, 1, hal_state} ->
          hal.sleep(100)
          wait_until_idle_loop(hal, hal_state, timeout_ms, start_time)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Initialize the display with default settings.
  """
  def init(hal, hal_state) do
    Logger.info("Display: Initializing Waveshare 2.9\" e-ink display")

    with {:ok, hal_state} <- reset(hal, hal_state),
         {:ok, hal_state} <- wait_until_idle(hal, hal_state),
         {:ok, hal_state} <- send_command(hal, hal_state, @commands.sw_reset),
         {:ok, hal_state} <- wait_until_idle(hal, hal_state),
         {:ok, hal_state} <- send_command(hal, hal_state, @commands.driver_output_control),
         {:ok, hal_state} <- send_data(hal, hal_state, <<0x27, 0x01, 0x00>>),
         {:ok, hal_state} <- send_command(hal, hal_state, @commands.data_entry_mode),
         {:ok, hal_state} <- send_data(hal, hal_state, <<0x03>>),
         {:ok, hal_state} <- set_memory_area(hal, hal_state, 0, 0, @width - 1, @height - 1),
         {:ok, hal_state} <- send_command(hal, hal_state, @commands.border_waveform_control),
         {:ok, hal_state} <- send_data(hal, hal_state, <<0x05>>),
         {:ok, hal_state} <- send_command(hal, hal_state, @commands.temperature_sensor_control),
         {:ok, hal_state} <- send_data(hal, hal_state, <<0x80>>),
         {:ok, hal_state} <- set_memory_pointer(hal, hal_state, 0, 0),
         {:ok, hal_state} <- wait_until_idle(hal, hal_state) do
      Logger.info("Display: Initialization complete")
      {:ok, hal_state}
    else
      {:error, reason} = error ->
        Logger.error("Display: Initialization failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Set the memory area for writing.
  """
  def set_memory_area(hal, hal_state, x_start, y_start, x_end, y_end) do
    with {:ok, hal_state} <-
           send_command(hal, hal_state, @commands.set_ram_x_address_start_end_position),
         {:ok, hal_state} <- send_data(hal, hal_state, <<div(x_start, 8), div(x_end, 8)>>),
         {:ok, hal_state} <-
           send_command(hal, hal_state, @commands.set_ram_y_address_start_end_position),
         {:ok, hal_state} <- send_data(hal, hal_state, <<y_start::little-16, y_end::little-16>>) do
      {:ok, hal_state}
    end
  end

  @doc """
  Set the memory pointer for writing.
  """
  def set_memory_pointer(hal, hal_state, x, y) do
    with {:ok, hal_state} <- send_command(hal, hal_state, @commands.set_ram_x_address_counter),
         {:ok, hal_state} <- send_data(hal, hal_state, <<div(x, 8)>>),
         {:ok, hal_state} <- send_command(hal, hal_state, @commands.set_ram_y_address_counter),
         {:ok, hal_state} <- send_data(hal, hal_state, <<y::little-16>>) do
      {:ok, hal_state}
    end
  end

  @doc """
  Display image data on the screen.
  This function is kept for backward compatibility and defaults to partial update.
  """
  def display_frame(hal, hal_state, image_data) when is_binary(image_data) do
    display_frame_partial(hal, hal_state, image_data)
  end

  @doc """
  Display image data with partial update (fast, ~2 seconds).
  """
  def display_frame_partial(hal, hal_state, image_data) when is_binary(image_data) do
    Logger.debug("Display: Updating frame with partial update - #{byte_size(image_data)} bytes")

    expected_size = div(@width, 8) * @height

    if byte_size(image_data) != expected_size do
      Logger.error(
        "Display: Invalid image data size. Expected #{expected_size}, got #{byte_size(image_data)}"
      )

      {:error, :invalid_image_size}
    else
      with {:ok, hal_state} <- send_command(hal, hal_state, @commands.write_ram),
           {:ok, hal_state} <- send_data(hal, hal_state, image_data),
           {:ok, hal_state} <- partial_update(hal, hal_state) do
        Logger.debug("Display: Partial frame update complete")
        {:ok, hal_state}
      end
    end
  end

  @doc """
  Display image data with full refresh (slower, ~15 seconds).
  """
  def display_frame_full(hal, hal_state, image_data) when is_binary(image_data) do
    Logger.debug("Display: Updating frame with full refresh - #{byte_size(image_data)} bytes")

    expected_size = div(@width, 8) * @height

    if byte_size(image_data) != expected_size do
      Logger.error(
        "Display: Invalid image data size. Expected #{expected_size}, got #{byte_size(image_data)}"
      )

      {:error, :invalid_image_size}
    else
      with {:ok, hal_state} <- send_command(hal, hal_state, @commands.write_ram),
           {:ok, hal_state} <- send_data(hal, hal_state, image_data),
           {:ok, hal_state} <- full_refresh(hal, hal_state) do
        Logger.debug("Display: Full frame refresh complete")
        {:ok, hal_state}
      end
    end
  end

  @doc """
  Clear the display to white using full refresh.
  """
  def clear(hal, hal_state) do
    Logger.debug("Display: Clearing to white with full refresh")

    # Create white image data (all bits set to 1)
    image_size = div(@width, 8) * @height
    white_data = :binary.copy(<<0xFF>>, image_size)

    display_frame_full(hal, hal_state, white_data)
  end

  @doc """
  Turn on the display update.
  This function is kept for backward compatibility and defaults to partial update.
  """
  def turn_on_display(hal, hal_state) do
    partial_update(hal, hal_state)
  end

  @doc """
  Perform a partial update of the display (fast, ~2 seconds).
  Only updates changed pixels but can cause ghosting over time.
  """
  def partial_update(hal, hal_state) do
    Logger.debug("Display: Performing partial update")

    with {:ok, hal_state} <- send_command(hal, hal_state, @commands.display_update_control_2),
         {:ok, hal_state} <- send_data(hal, hal_state, <<0xC7>>),
         {:ok, hal_state} <- send_command(hal, hal_state, @commands.master_activation),
         {:ok, hal_state} <- send_command(hal, hal_state, @commands.terminate_frame_read_write),
         {:ok, hal_state} <- wait_until_idle(hal, hal_state) do
      {:ok, hal_state}
    end
  end

  @doc """
  Perform a full refresh of the display (slower, ~15 seconds).
  Resets the entire display and eliminates ghosting.
  """
  def full_refresh(hal, hal_state) do
    Logger.debug("Display: Performing full refresh")

    with {:ok, hal_state} <- send_command(hal, hal_state, @commands.display_update_control_2),
         {:ok, hal_state} <- send_data(hal, hal_state, <<0xF7>>),
         {:ok, hal_state} <- send_command(hal, hal_state, @commands.master_activation),
         {:ok, hal_state} <- send_command(hal, hal_state, @commands.terminate_frame_read_write),
         {:ok, hal_state} <- wait_until_idle(hal, hal_state) do
      {:ok, hal_state}
    end
  end

  @doc """
  Put display into sleep mode.
  """
  def sleep(hal, hal_state) do
    Logger.debug("Display: Entering sleep mode")

    with {:ok, hal_state} <- send_command(hal, hal_state, @commands.deep_sleep_mode),
         {:ok, hal_state} <- send_data(hal, hal_state, <<0x01>>) do
      {:ok, hal_state}
    end
  end
end
