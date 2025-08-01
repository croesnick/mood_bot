defmodule MoodBot.Display.Driver do
  @moduledoc """
  Low-level driver for Waveshare 2.9" e-ink display (epd2in9_V2) following Python reference implementation.

  This module implements the exact command sequences and protocols from the Waveshare Python driver,
  ensuring hardware compatibility and predictable behavior. All timing constants, command codes,
  and initialization sequences match the reference implementation.

  ## Features

  - **Hardware Initialization**: Complete initialization sequence with precise timing
  - **Display Updates**: Both partial (fast) and full (slow) refresh modes
  - **Power Management**: Deep sleep mode with proper shutdown sequence
  - **Data Transfer**: Chunked SPI transfers for large image data
  - **LUT Management**: Look-Up Table loading for refresh timing control
  - **Testing Functions**: Hardware connectivity and data transfer validation

  ## Display Specifications

  - **Resolution**: 128 × 296 pixels (monochrome)
  - **Interface**: SPI communication with GPIO control signals
  - **Image Format**: 1 bit per pixel, 4736 bytes total (128 × 296 ÷ 8)
  - **Refresh Types**: Partial (~2-3 seconds) and Full (~15-20 seconds)

  ## Reference Implementation

  This implementation follows the Waveshare Python driver exactly:
  - [Python Driver Source](https://github.com/waveshareteam/e-Paper/blob/master/RaspberryPi_JetsonNano/python/lib/waveshare_epd/epd2in9_V2.py)
  - Command codes and timing constants match the reference
  - Initialization and shutdown sequences are identical
  - LUT data and waveform timing preserved

  ## Usage

  This module is typically used through the `MoodBot.Display` GenServer,
  which provides higher-level state management and error handling.

      # Initialize display hardware
      {:ok, hal_state} = Driver.init(hal_module, hal_state)

      # Display image with full refresh
      {:ok, hal_state} = Driver.display_frame_full(hal_module, hal_state, image_data)

      # Put display to sleep
      {:ok, hal_state} = Driver.sleep(hal_module, hal_state)
  """

  require Logger
  import Bitwise

  alias MoodBot.Display.HAL

  # Display specifications
  @width 128
  @height 296

  # Commands for Waveshare 2.9" V2 display
  # Hardware control commands
  # Configure gate driver timing and direction
  @command_driver_output_control 0x01
  # Control power-on sequence for gate driver
  @command_booster_soft_start_control 0x0C
  # Set which gate line to start scanning from
  @command_gate_scan_start_position 0x0F
  # Put display into low-power sleep mode
  @command_deep_sleep_mode 0x10
  # Set how RAM address increments during writes
  @command_data_entry_mode 0x11
  # Software reset - reinitialize display controller
  @command_software_reset 0x12
  # Enable/disable internal temperature sensor
  @command_temperature_sensor_control 0x1A

  # Display update commands
  # Trigger display update after setting parameters
  @command_master_activation 0x20
  # Configure display update sequence options
  @command_display_update_control_1 0x21
  # Set display update mode (full/partial refresh)
  @command_display_update_control_2 0x22

  # Memory access commands
  # Write image data to display RAM
  @command_write_ram 0x24
  # Write black/white image data (same as write_ram)
  @command_write_ram_bw 0x24
  # Write red channel data (for 3-color displays)
  @command_write_ram_red 0x26
  # Set VCOM (common voltage) level
  @command_write_vcom_register 0x2C
  # Load Look-Up Table for waveform control
  @command_write_lut_register 0x32

  # Voltage control commands
  # Gate voltage configuration
  @command_gate_voltage 0x03
  # Source voltage configuration
  @command_source_voltage 0x04
  # LUT configuration command
  @command_lut_end_option 0x3F

  # Timing control commands
  # Set dummy line period for gate driver
  @command_set_dummy_line_period 0x3A
  # Set gate driving time
  @command_set_gate_time 0x3B
  # Control border color during refresh
  @command_border_waveform_control 0x3C

  # RAM addressing commands
  # Define X-axis memory window (columns)
  @command_set_ram_x_address_start_end_position 0x44
  # Define Y-axis memory window (rows)
  @command_set_ram_y_address_start_end_position 0x45
  # Set current X position for writing
  @command_set_ram_x_address_counter 0x4E
  # Set current Y position for writing
  @command_set_ram_y_address_counter 0x4F

  # Special commands
  # End frame read/write operation
  @command_terminate_frame_read_write 0xFF

  @doc """
  Get display dimensions in pixels.

  Returns the fixed dimensions of the Waveshare 2.9" V2 display.

  ## Examples

      {width, height} = MoodBot.Display.Driver.dimensions()
      # {128, 296}
  """
  @spec dimensions() :: {pos_integer(), pos_integer()}
  def dimensions, do: {@width, @height}

  @doc """
  Initialize the display following the exact Waveshare Python driver sequence.

  Performs complete hardware initialization including:
  - Hardware reset with precise 50ms-2ms-50ms timing from DRIVER.md
  - Software reset and busy pin polling
  - Driver output control configuration (0x01: 0x27, 0x01, 0x00)
  - Data entry mode setup (0x11: 0x03 for X/Y increment)
  - Memory area and pointer initialization
  - Display update control configuration
  - WS_20_30 LUT loading for proper refresh timing

  ## Parameters
  - `hal` - HAL implementation module
  - `hal_state` - HAL state from previous operations

  ## Reference
  Based on [Python driver init sequence](https://github.com/waveshareteam/e-Paper/blob/master/RaspberryPi_JetsonNano/python/lib/waveshare_epd/epd2in9_V2.py#L144)
  """
  @spec init(HAL.impl(), term()) :: {:ok, term()} | {:error, term()}
  def init(hal, hal_state) do
    Logger.info("Display: Initializing Waveshare 2.9\" V2 e-ink display")

    with {:ok, hal_state} <- reset(hal, hal_state),

         {:ok, hal_state} <- wait_until_idle(hal, hal_state),
         {:ok, hal_state} <- send_command(hal, hal_state, @command_software_reset),
         {:ok, hal_state} <- wait_until_idle(hal, hal_state),

         {:ok, hal_state} <- send_command(hal, hal_state, @command_driver_output_control),
         {:ok, hal_state} <- send_data(hal, hal_state, <<0x27>>),
         {:ok, hal_state} <- send_data(hal, hal_state, <<0x01>>),
         {:ok, hal_state} <- send_data(hal, hal_state, <<0x00>>),

         {:ok, hal_state} <- send_command(hal, hal_state, @command_data_entry_mode),
         {:ok, hal_state} <- send_data(hal, hal_state, <<0x03>>),

         {:ok, hal_state} <- set_memory_area(hal, hal_state, 0, 0, @width - 1, @height - 1),

         {:ok, hal_state} <- send_command(hal, hal_state, @command_display_update_control_1),
         {:ok, hal_state} <- send_data(hal, hal_state, <<0x00>>),
         {:ok, hal_state} <- send_data(hal, hal_state, <<0x80>>),

         {:ok, hal_state} <- set_memory_pointer(hal, hal_state, 0, 0),
         {:ok, hal_state} <- wait_until_idle(hal, hal_state),

         {:ok, hal_state} <- set_lut_ws_20_30(hal, hal_state) do
      Logger.info("Display: Initialization complete")
      {:ok, hal_state}
    else
      {:error, reason} ->
        Logger.error("Display: Initialization failed",
          error: reason,
          hal_module: hal
        )

        {:error, {:init_failed, reason}}
    end
  end

  @doc """
  Hardware reset sequence with precise timing from DRIVER.md.

  Performs the critical reset sequence required by the e-ink controller:
  1. Set RST pin HIGH (50ms delay)
  2. Set RST pin LOW (2ms delay)
  3. Set RST pin HIGH (50ms delay)

  The timing is critical and matches the Python driver specification exactly.

  ## Parameters
  - `hal` - HAL implementation module
  - `hal_state` - HAL state from previous operations

  ## Reference
  [Python driver reset sequence](https://github.com/waveshareteam/e-Paper/blob/master/RaspberryPi_JetsonNano/python/lib/waveshare_epd/epd2in9_V2.py#L144)
  """
  @spec reset(HAL.impl(), term()) :: {:ok, term()} | {:error, term()}
  def reset(hal, hal_state) do
    Logger.debug("Display: Hardware reset")

    with {:ok, hal_state} <- hal.gpio_set_rst(hal_state, 1),
         :ok <- hal.sleep(50),
         {:ok, hal_state} <- hal.gpio_set_rst(hal_state, 0),
         :ok <- hal.sleep(2),
         {:ok, hal_state} <- hal.gpio_set_rst(hal_state, 1),
         :ok <- hal.sleep(50) do
      {:ok, hal_state}
    end
  end

  @doc """
  Wait for the display to become ready by polling the BUSY pin.

  Continuously polls the BUSY pin until it goes LOW, indicating the display
  has finished processing the previous command. Essential for proper timing
  between commands to prevent display corruption.

  ## Parameters
  - `hal` - HAL implementation module
  - `hal_state` - HAL state from previous operations
  - `timeout_ms` - Maximum wait time in milliseconds (default: 10,000)
  """
  @spec wait_until_idle(HAL.impl(), term(), non_neg_integer()) :: {:ok, term()} | {:error, term()}
  def wait_until_idle(hal, hal_state, timeout_ms \\ 15_000) do
    Logger.debug("Display: Busy")
    wait_until_idle_loop(hal, hal_state, timeout_ms, System.monotonic_time(:millisecond))
  end

  defp wait_until_idle_loop(hal, hal_state, timeout_ms, start_time) do
    current_time = System.monotonic_time(:millisecond)

    if current_time - start_time > timeout_ms do
      Logger.error("Display: Timeout waiting for idle state",
        timeout_ms: timeout_ms,
        elapsed_ms: current_time - start_time,
        hal_module: hal
      )

      {:error, :timeout}
    else
      case hal.gpio_read_busy(hal_state) do
        {:ok, 0, hal_state} ->
          Logger.debug("Display: Ready (idle)")
          {:ok, hal_state}

        {:ok, 1, hal_state} ->
          Process.sleep(10)
          wait_until_idle_loop(hal, hal_state, timeout_ms, start_time)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  @doc """
  Send a command byte to the display.

  Sets DC pin LOW (command mode) and sends the command via SPI.
  """
  @spec send_command(HAL.impl(), term(), integer()) :: {:ok, term()} | {:error, term()}
  def send_command(hal, hal_state, command) when is_integer(command) do
    Logger.debug("Display: Sending command 0x#{Integer.to_string(command, 16)}")

    # FIXME Instead of gpio_set_dc, we could have a hal.gpio_set_command_mode/1.
    #       And similarly, a hal.gpio_set_data_mode/1.
    #       Or clarify if these helper functions should exist on the driver side.
    with {:ok, hal_state} <- hal.gpio_set_dc(hal_state, 0),
         {:ok, hal_state} <- hal.spi_write(hal_state, <<command>>) do
      {:ok, hal_state}
    end
  end

  @doc """
  Send data bytes to the display.

  Sets DC pin HIGH (data mode) and sends the data via SPI.
  """
  @spec send_data(HAL.impl(), term(), binary()) :: {:ok, term()} | {:error, term()}
  def send_data(hal, hal_state, data) when is_binary(data) do
    Logger.debug("Display: Sending #{byte_size(data)} bytes of data")

    with {:ok, hal_state} <- hal.gpio_set_dc(hal_state, 1),
         {:ok, hal_state} <- hal.spi_write(hal_state, data) do
      {:ok, hal_state}
    end
  end

  @doc """
  Set the memory area for writing.
  """
  def set_memory_area(hal, hal_state, x_start, y_start, x_end, y_end) do
    Logger.debug("Display: Setting memory area",
      x_start: x_start,
      y_start: y_start,
      x_end: x_end,
      y_end: y_end
    )

    with {:ok, hal_state} <-
           send_command(hal, hal_state, @command_set_ram_x_address_start_end_position),
         {:ok, hal_state} <- send_data(hal, hal_state, <<(x_start >>> 3) &&& 0xFF>>),
         {:ok, hal_state} <- send_data(hal, hal_state, <<(x_end >>> 3) &&& 0xFF>>),
         {:ok, hal_state} <-
           send_command(hal, hal_state, @command_set_ram_y_address_start_end_position),
         {:ok, hal_state} <- send_data(hal, hal_state, <<y_start &&& 0xFF>>),
         {:ok, hal_state} <- send_data(hal, hal_state, <<(y_start >>> 8) &&& 0xFF>>),
         {:ok, hal_state} <- send_data(hal, hal_state, <<y_end &&& 0xFF>>),
         {:ok, hal_state} <- send_data(hal, hal_state, <<(y_end >>> 8) &&& 0xFF>>) do
      {:ok, hal_state}
    end
  end

  @doc """
  Set the memory pointer for writing.
  """
  def set_memory_pointer(hal, hal_state, x, y) do
    Logger.debug("Display: Setting memory pointer",
      x: x,
      y: y
    )

    with {:ok, hal_state} <- send_command(hal, hal_state, @command_set_ram_x_address_counter),
         # highest 3 bits are ignored
         {:ok, hal_state} <- send_data(hal, hal_state, <<x &&& 0xFF>>),

         {:ok, hal_state} <- send_command(hal, hal_state, @command_set_ram_y_address_counter),
         {:ok, hal_state} <- send_data(hal, hal_state, <<y &&& 0xFF>>),
         {:ok, hal_state} <- send_data(hal, hal_state, <<(y >>> 8) &&& 0xFF>>) do
      {:ok, hal_state}
    end
  end

  @doc """
  Display image data using partial update (legacy function).

  This function is kept for backward compatibility and defaults to partial update.
  For new code, use `display_frame_partial/3` or `display_frame_full/3` explicitly.

  ## Parameters
  - `hal` - HAL implementation module
  - `hal_state` - HAL state from previous operations
  - `image_data` - Binary image data (4736 bytes for 128×296 display)
  """
  @spec display_frame(HAL.impl(), term(), binary()) :: {:ok, term()} | {:error, term()}
  def display_frame(hal, hal_state, image_data) when is_binary(image_data) do
    display_frame_partial(hal, hal_state, image_data)
  end

  @doc """
  Display image data with partial update (fast, ~2-3 seconds).

  Performs a fast partial update that only refreshes changed pixels.
  Faster than full refresh but can cause ghosting over time. Should be
  followed by a full refresh after several partial updates.

  ## Parameters
  - `hal` - HAL implementation module
  - `hal_state` - HAL state from previous operations
  - `image_data` - Binary image data (exactly 4736 bytes)

  ## Image Format
  - Size: 4736 bytes (128 × 296 ÷ 8)
  - Format: 1 bit per pixel, 0=black, 1=white
  """
  @spec display_frame_partial(HAL.impl(), term(), binary()) ::
          {:ok, term()} | {:error, :invalid_image_size | term()}
  def display_frame_partial(hal, hal_state, image_data) when is_binary(image_data) do
    Logger.debug("Display: Updating frame with partial update - #{byte_size(image_data)} bytes")

    expected_size = div(@width, 8) * @height

    if byte_size(image_data) != expected_size do
      Logger.error(
        "Display: Invalid image data size. Expected #{expected_size}, got #{byte_size(image_data)}"
      )

      {:error, :invalid_image_size}
    else
      with {:ok, hal_state} <- send_command(hal, hal_state, @command_write_ram),
           {:ok, hal_state} <- send_data(hal, hal_state, image_data),
           {:ok, hal_state} <- partial_update(hal, hal_state) do
        Logger.debug("Display: Partial frame update complete")
        {:ok, hal_state}
      end
    end
  end

  @doc """
  Display image data with full refresh (slower, ~15-20 seconds).

  Performs a complete display refresh that updates all pixels and eliminates
  ghosting artifacts. Takes significantly longer than partial updates but
  provides the cleanest, most accurate display output.

  ## Parameters
  - `hal` - HAL implementation module
  - `hal_state` - HAL state from previous operations
  - `image_data` - Binary image data (exactly 4736 bytes)

  ## Image Format
  - Size: 4736 bytes (128 × 296 ÷ 8)
  - Format: 1 bit per pixel, 0=black, 1=white
  """
  @spec display_frame_full(HAL.impl(), term(), binary()) ::
          {:ok, term()} | {:error, :invalid_image_size | term()}
  def display_frame_full(hal, hal_state, image_data) when is_binary(image_data) do
    Logger.debug("Display: Updating frame with full refresh - #{byte_size(image_data)} bytes")

    expected_size = div(@width, 8) * @height

    # FIXME Can't this be handled by proper typing?
    if byte_size(image_data) != expected_size do
      Logger.error(
        "Display: Invalid image data size. Expected #{expected_size}, got #{byte_size(image_data)}"
      )

      {:error, :invalid_image_size}
    else
      with {:ok, hal_state} <- send_command(hal, hal_state, @command_write_ram),
           {:ok, hal_state} <- send_data(hal, hal_state, image_data),
           {:ok, hal_state} <- full_refresh(hal, hal_state) do
        Logger.debug("Display: Full frame refresh complete")
        {:ok, hal_state}
      end
    end
  end

  @spec clear_display(atom(), any(), binary()) :: {:error, any()} | {:ok, any()}
  def clear_display(hal, hal_state, image_data) when is_binary(image_data) do
    Logger.debug("Display: clearing display")

    with {:ok, hal_state} <- send_command(hal, hal_state, @command_write_ram_bw),
         {:ok, hal_state} <- send_data(hal, hal_state, image_data),
         {:ok, hal_state} <- turn_on_display(hal, hal_state),

         {:ok, hal_state} <- send_command(hal, hal_state, @command_write_ram_red),
         {:ok, hal_state} <- send_data(hal, hal_state, image_data),
         {:ok, hal_state} <- turn_on_display(hal, hal_state) do

      Logger.debug("Display: Full frame refresh complete")
      {:ok, hal_state}
    end
  end

  def turn_on_display(hal, hal_state) do
    with {:ok, hal_state} <- send_command(hal, hal_state, @command_display_update_control_2),
         {:ok, hal_state} <- send_data(hal, hal_state, <<0xC7>>),
         {:ok, hal_state} <- send_command(hal, hal_state, @command_master_activation),
         {:ok, hal_state} <- wait_until_idle(hal, hal_state) do

      Logger.debug("Display: Turned display on")
      {:ok, hal_state}
    end
  end

  @doc """
  Clear the display to white using full refresh.
  """
  @spec clear(HAL.impl(), term()) :: {:ok, term()} | {:error, term()}
  def clear(hal, hal_state) do
    Logger.debug("Display: Clearing to white with full refresh")

    white_data = generate_solid_image(:white)
    display_frame_full(hal, hal_state, white_data)
  end

  @doc """
  Fill the display with black using full refresh.
  """
  def fill_black(hal, hal_state) do
    Logger.debug("Display: Filling with black with full refresh")

    black_data = generate_solid_image(:black)
    display_frame_full(hal, hal_state, black_data)
  end

  @doc """
  Generate solid color image data.
  """
  def generate_solid_image(:white) do
    image_size = div(@width, 8) * @height
    :binary.copy(<<0xFF>>, image_size)
  end

  def generate_solid_image(:black) do
    image_size = div(@width, 8) * @height
    :binary.copy(<<0x00>>, image_size)
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

    with {:ok, hal_state} <- send_command(hal, hal_state, @command_display_update_control_2),
         {:ok, hal_state} <- send_data(hal, hal_state, <<0x0F>>),
         {:ok, hal_state} <- send_command(hal, hal_state, @command_master_activation),
         {:ok, hal_state} <- send_command(hal, hal_state, @command_terminate_frame_read_write),
         {:ok, hal_state} <- wait_until_idle(hal, hal_state, 10_000) do
      {:ok, hal_state}
    end
  end

  @doc """
  Perform a full refresh of the display (slower, ~15 seconds).
  Resets the entire display and eliminates ghosting.
  """
  def full_refresh(hal, hal_state) do
    Logger.debug("Display: Performing full refresh")

    with {:ok, hal_state} <- send_command(hal, hal_state, @command_display_update_control_2),
         {:ok, hal_state} <- send_data(hal, hal_state, <<0x00>>),
         {:ok, hal_state} <- send_command(hal, hal_state, @command_master_activation),
         {:ok, hal_state} <- send_command(hal, hal_state, @command_terminate_frame_read_write),
         {:ok, hal_state} <- wait_until_idle(hal, hal_state, 25_000) do
      {:ok, hal_state}
    end
  end

  @doc """
  Put display into deep sleep mode following Python driver sequence.

  Sends the deep sleep command (0x10) with activation data (0x01) as specified
  in DRIVER.md. In sleep mode, the display consumes minimal power while
  retaining the last displayed image.

  ## Parameters
  - `hal` - HAL implementation module
  - `hal_state` - HAL state from previous operations

  ## Reference
  Based on [Python driver sleep sequence](https://github.com/waveshareteam/e-Paper/blob/master/RaspberryPi_JetsonNano/python/lib/waveshare_epd/epd2in9_V2.py#L520)
  """
  @spec sleep(HAL.impl(), term()) :: {:ok, term()} | {:error, term()}
  def sleep(hal, hal_state) do
    Logger.debug("Display: Entering sleep mode")

    with {:ok, hal_state} <- send_command(hal, hal_state, @command_deep_sleep_mode),
         {:ok, hal_state} <- send_data(hal, hal_state, <<0x01>>) do
      {:ok, hal_state}
    end
  end

  @doc """
  Test basic SPI communication by sending a simple command.
  """
  def test_spi_communication(hal, hal_state) do
    Logger.debug("Display: Testing basic SPI communication")

    # Try sending a simple software reset command
    with {:ok, hal_state} <- send_command(hal, hal_state, @command_software_reset) do
      Logger.debug("Display: Basic SPI test successful")
      {:ok, hal_state}
    else
      {:error, reason} = error ->
        Logger.error("Display: Basic SPI test failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Test sending a small amount of data to the display.
  """
  def test_small_data_write(hal, hal_state) do
    Logger.debug("Display: Testing small data write")

    # Try sending just a few bytes of data
    small_data = <<0xFF, 0x00, 0xFF, 0x00>>

    with {:ok, hal_state} <- send_command(hal, hal_state, @command_write_ram),
         {:ok, hal_state} <- send_data(hal, hal_state, small_data) do
      Logger.debug("Display: Small data write test successful")
      {:ok, hal_state}
    else
      {:error, reason} = error ->
        Logger.error("Display: Small data write test failed: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Test sending progressively larger data chunks to find transfer limit.
  """
  def test_large_data_write(hal, hal_state, size \\ 1024) do
    Logger.debug("Display: Testing large data write (#{size} bytes)")

    # Create test data of specified size
    test_data = :binary.copy(<<0xFF>>, size)

    with {:ok, hal_state} <- send_command(hal, hal_state, @command_write_ram),
         {:ok, hal_state} <- send_data(hal, hal_state, test_data) do
      Logger.debug("Display: Large data write test successful (#{size} bytes)")
      {:ok, hal_state}
    else
      {:error, reason} = error ->
        Logger.error("Display: Large data write test failed (#{size} bytes): #{inspect(reason)}")
        error
    end
  end

  @doc """
  Set the LUT (Look-Up Table) for WS_20_30 waveform.
  This is required for proper V2 display initialization.
  """
  def set_lut_ws_20_30(hal, hal_state) do
    Logger.debug("Display: Setting LUT WS_20_30")

    # fmt:off
    lut_data = <<
      0x80,	0x66,	0x0,	0x0,	0x0,	0x0,	0x0,	0x0,	0x40,	0x0,	0x0,	0x0,
      0x10,	0x66,	0x0,	0x0,	0x0,	0x0,	0x0,	0x0,	0x20,	0x0,	0x0,	0x0,
      0x80,	0x66,	0x0,	0x0,	0x0,	0x0,	0x0,	0x0,	0x40,	0x0,	0x0,	0x0,
      0x10,	0x66,	0x0,	0x0,	0x0,	0x0,	0x0,	0x0,	0x20,	0x0,	0x0,	0x0,
      0x0,	0x0,	0x0,	0x0,	0x0,	0x0,	0x0,	0x0,	0x0,	0x0,	0x0,	0x0,
      0x14,	0x8,	0x0,	0x0,	0x0,	0x0,	0x2,
      0xA,	0xA,	0x0,	0xA,	0xA,	0x0,	0x1,
      0x0,	0x0,	0x0,	0x0,	0x0,	0x0,	0x0,
      0x0,	0x0,	0x0,	0x0,	0x0,	0x0,	0x0,
      0x0,	0x0,	0x0,	0x0,	0x0,	0x0,	0x0,
      0x0,	0x0,	0x0,	0x0,	0x0,	0x0,	0x0,
      0x0,	0x0,	0x0,	0x0,	0x0,	0x0,	0x0,
      0x0,	0x0,	0x0,	0x0,	0x0,	0x0,	0x0,
      0x14,	0x8,	0x0,	0x1,	0x0,	0x0,	0x1,
      0x0,	0x0,	0x0,	0x0,	0x0,	0x0,	0x1,
      0x0,	0x0,	0x0,	0x0,	0x0,	0x0,	0x0,
      0x0,	0x0,	0x0,	0x0,	0x0,	0x0,	0x0,
      0x44,	0x44,	0x44,	0x44,	0x44,	0x44,	0x0,	0x0,	0x0,
      0x22,	0x17,	0x41,	0x0,	0x32,	0x36
    >>
    # fmt:on

    # Convert to list for easy indexed access
    lut_bytes = :binary.bin_to_list(lut_data)

    with {:ok, hal_state} <- send_command(hal, hal_state, @command_write_lut_register),
         {:ok, hal_state} <- send_lut_bytes_individually(hal, hal_state, lut_bytes, 0, 152),
         {:ok, hal_state} <- wait_until_idle(hal, hal_state),

         {:ok, hal_state} <- send_command(hal, hal_state, @command_lut_end_option),
         {:ok, hal_state} <- send_data(hal, hal_state, <<Enum.at(lut_bytes, 153)>>),
         {:ok, hal_state} <- send_command(hal, hal_state, @command_gate_voltage),
         {:ok, hal_state} <- send_data(hal, hal_state, <<Enum.at(lut_bytes, 154)>>),
         {:ok, hal_state} <- send_command(hal, hal_state, @command_source_voltage),
         {:ok, hal_state} <- send_data(hal, hal_state, <<Enum.at(lut_bytes, 155)>>), # VSH
         {:ok, hal_state} <- send_data(hal, hal_state, <<Enum.at(lut_bytes, 156)>>), # VSH2
         {:ok, hal_state} <- send_data(hal, hal_state, <<Enum.at(lut_bytes, 157)>>), # VSL
         {:ok, hal_state} <- send_command(hal, hal_state, @command_write_vcom_register),
         {:ok, hal_state} <- send_data(hal, hal_state, <<Enum.at(lut_bytes, 158)>>) do
      {:ok, hal_state}
    end
  end

  # Helper function to send LUT bytes individually (matching Python for loop)
  defp send_lut_bytes_individually(_hal, hal_state, _lut_bytes, index, max_index)
       when index > max_index do
    {:ok, hal_state}
  end

  defp send_lut_bytes_individually(hal, hal_state, lut_bytes, index, max_index) do
    with {:ok, hal_state} <- send_data(hal, hal_state, <<Enum.at(lut_bytes, index)>>) do
      send_lut_bytes_individually(hal, hal_state, lut_bytes, index + 1, max_index)
    end
  end
end
