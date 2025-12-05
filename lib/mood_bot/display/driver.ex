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
      {:ok, hal_state} = Driver.render_image(hal_module, hal_state, image_data)

      # Put display to sleep
      {:ok, hal_state} = Driver.sleep(hal_module, hal_state)
  """

  use TypedStruct

  require Logger
  import Bitwise

  alias MoodBot.Display.HAL
  alias MoodBot.Display.HAL.LookUpTables

  @typedoc """
  Driver state containing HAL module, HAL state, and initialization status.
  """
  typedstruct do
    field(:hal_module, module())
    field(:hal_state, HAL.hal_state())
    field(:initialized?, boolean(), default: false)
  end

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
  # TODO Find out what this command does (look up in fact sheet)
  @command_partial_update 0x37

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
  Initialize the display driver with automatic HAL selection.

  Performs complete hardware initialization including:
  - Automatic HAL module selection based on Mix.target()
  - HAL initialization with provided configuration
  - Hardware reset with precise timing from DRIVER.md
  - Software reset and busy pin polling
  - Driver output control configuration
  - Data entry mode setup
  - Memory area and pointer initialization
  - Display update control configuration
  - WS_20_30 LUT loading for proper refresh timing

  ## Reference
  Based on [Python driver init sequence](https://github.com/waveshareteam/e-Paper/blob/master/RaspberryPi_JetsonNano/python/lib/waveshare_epd/epd2in9_V2.py#L144)
  """
  @spec init() :: {:ok, t()} | {:error, term()}
  def init() do
    [hal_module: hal_module, spi_device: spi_device, gpio: gpio] =
      Application.get_env(:mood_bot, __MODULE__)

    hal_config = %{
      spi_device: spi_device,
      pwr_gpio: gpio.pwr_gpio,
      dc_gpio: gpio.dc_gpio,
      rst_gpio: gpio.rst_gpio,
      busy_gpio: gpio.busy_gpio
    }

    Logger.info(
      "Driver: Initializing Waveshare 2.9\" V2 e-ink display with #{inspect(hal_module)}"
    )

    case hal_module.init(hal_config) do
      {:ok, hal_state} ->
        driver_state = %__MODULE__{
          hal_module: hal_module,
          hal_state: hal_state,
          initialized?: false
        }

        case init_display_hardware(driver_state) do
          {:ok, updated_driver_state} ->
            final_state = %{updated_driver_state | initialized?: true}
            {:ok, final_state}

          {:error, reason} ->
            Logger.error("Driver: Hardware initialization failed",
              error: reason,
              hal_module: hal_module
            )

            {:error, {:init_failed, reason}}
        end

      {:error, reason} ->
        Logger.error("Driver: HAL initialization failed", error: reason, hal_module: hal_module)
        {:error, {:hal_init_failed, reason}}
    end
  end

  @spec init_display_hardware(t()) :: {:ok, t()} | {:error, term()}
  defp init_display_hardware(driver_state) do
    %{hal_module: hal, hal_state: hal_state} = driver_state

    with {:ok, hal_state} <- reset_hal(hal, hal_state),
         {:ok, hal_state} <- wait_until_idle_hal(hal, hal_state),
         {:ok, hal_state} <-
           send_command_hal(hal, hal_state, @command_software_reset),
         {:ok, hal_state} <- wait_until_idle_hal(hal, hal_state),
         {:ok, hal_state} <-
           send_command_hal(hal, hal_state, @command_driver_output_control),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x27>>),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x01>>),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x00>>),
         {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_data_entry_mode),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x03>>),
         {:ok, hal_state} <- set_memory_area_hal(hal, hal_state, 0, 0, @width - 1, @height - 1),
         {:ok, hal_state} <-
           send_command_hal(hal, hal_state, @command_display_update_control_1),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x00>>),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x80>>),
         {:ok, hal_state} <- set_memory_pointer(hal, hal_state, 0, 0),
         {:ok, hal_state} <- wait_until_idle_hal(hal, hal_state),
         {:ok, hal_state} <- set_lut(hal, hal_state, LookUpTables.wf_20_30()) do
      Logger.info("Driver: Hardware initialization complete")
      {:ok, %{driver_state | hal_state: hal_state}}
    else
      {:error, reason} ->
        Logger.error("Driver: Hardware initialization failed", error: reason, hal_module: hal)
        {:error, {:hardware_init_failed, reason}}
    end
  end

  @doc """
  Initialize the display driver with fast initialization sequence.

  Performs fast hardware initialization following the Python `init_Fast` sequence:
  - Same core initialization as `init/1`
  - Adds border waveform control command (0x3C with data 0x05)
  - Uses WF_FULL LUT instead of WS_20_30 for faster refresh timing

  This initialization method provides faster display updates at the cost of
  potentially reduced image quality compared to the standard initialization.

  ## Reference
  Based on [Python driver init_Fast sequence](https://github.com/waveshareteam/e-Paper/blob/master/RaspberryPi_JetsonNano/python/lib/waveshare_epd/epd2in9_V2.py#L272)
  """
  @spec init_fast() :: {:ok, t()} | {:error, term()}
  def init_fast() do
    %{hal_module: hal_module, spi_device: spi_device, gpio: gpio} =
      Application.get_env(:mood_bot, __MODULE__)

    Logger.info("Driver: Initializing Waveshare 2.9\" V2 e-ink display with fast mode")

    hal_config = %{
      spi_device: spi_device,
      pwr_gpio: gpio.pwr_gpio,
      dc_gpio: gpio.dc_gpio,
      rst_gpio: gpio.rst_gpio,
      busy_gpio: gpio.busy_gpio
    }

    case hal_module.init(hal_config) do
      {:ok, hal_state} ->
        driver_state = %__MODULE__{
          hal_module: hal_module,
          hal_state: hal_state,
          initialized?: false
        }

        case init_fast_display_hardware(driver_state) do
          {:ok, updated_driver_state} ->
            final_state = %{updated_driver_state | initialized?: true}
            {:ok, final_state}

          {:error, reason} ->
            Logger.error("Driver: Fast hardware initialization failed",
              error: reason,
              hal_module: hal_module
            )

            {:error, {:init_fast_failed, reason}}
        end

      {:error, reason} ->
        Logger.error("Driver: HAL initialization failed for fast mode",
          error: reason,
          hal_module: hal_module
        )

        {:error, {:hal_init_failed, reason}}
    end
  end

  @spec init_fast_display_hardware(t()) :: {:ok, t()} | {:error, term()}
  defp init_fast_display_hardware(driver_state) do
    %{hal_module: hal, hal_state: hal_state} = driver_state

    with {:ok, hal_state} <- reset_hal(hal, hal_state),
         {:ok, hal_state} <- wait_until_idle_hal(hal, hal_state),
         {:ok, hal_state} <-
           send_command_hal(hal, hal_state, @command_software_reset),
         {:ok, hal_state} <- wait_until_idle_hal(hal, hal_state),
         {:ok, hal_state} <-
           send_command_hal(hal, hal_state, @command_driver_output_control),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x27>>),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x01>>),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x00>>),
         {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_data_entry_mode),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x03>>),
         {:ok, hal_state} <- set_memory_area_hal(hal, hal_state, 0, 0, @width - 1, @height - 1),
         {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_border_waveform_control),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x05>>),
         {:ok, hal_state} <-
           send_command_hal(hal, hal_state, @command_display_update_control_1),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x00>>),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x80>>),
         {:ok, hal_state} <- set_memory_pointer(hal, hal_state, 0, 0),
         {:ok, hal_state} <- wait_until_idle_hal(hal, hal_state),
         {:ok, hal_state} <- set_lut(hal, hal_state, LookUpTables.wf_full()) do
      Logger.info("Driver: Fast hardware initialization complete")
      {:ok, %{driver_state | hal_state: hal_state}}
    else
      {:error, reason} ->
        Logger.error("Driver: Fast hardware initialization failed",
          error: reason,
          hal_module: hal
        )

        {:error, {:hardware_init_fast_failed, reason}}
    end
  end

  @doc """
  Put display into deep sleep mode.

  Sends the deep sleep command (0x10) with activation data (0x01).
  In sleep mode, the display consumes minimal power while retaining the last displayed image.

  To reactivate the display, call `activate/1` again.

  ## Reference
  Based on [Python driver sleep sequence](https://github.com/waveshareteam/e-Paper/blob/master/RaspberryPi_JetsonNano/python/lib/waveshare_epd/epd2in9_V2.py#L520)
  """
  @spec hibernate(t()) :: {:ok, t()} | {:error, term()}
  def hibernate(%__MODULE__{} = driver_state) do
    %{hal_module: hal, hal_state: hal_state} = driver_state

    case hibernate_hal(hal, hal_state) do
      {:ok, new_hal_state} ->
        {:ok, %{driver_state | hal_state: new_hal_state}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp hibernate_hal(hal, hal_state) do
    Logger.debug("Driver: Entering deep sleep mode")

    with {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_deep_sleep_mode),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x01>>),
         {:ok, hal_state} <- hal.sleep(hal_state, 2_000),
         {:ok, hal_state} <- hal.close(hal_state) do
      {:ok, hal_state}
    end
  end

  @doc """
  Hardware reset sequence with precise timing.
  TODO Add what's the effect of this reset.
  """
  @spec reset(t()) :: {:ok, t()} | {:error, term()}
  def reset(%__MODULE__{} = driver_state) do
    %{hal_module: hal, hal_state: hal_state} = driver_state

    Logger.debug("Driver: Hardware reset")

    with {:ok, hal_state} <- reset_hal(hal, hal_state) do
      {:ok, %{driver_state | hal_state: hal_state}}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp reset_hal(hal, hal_state) do
    Logger.debug("Driver: Hardware reset")

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
  Wait for the display to become ready by polling the BUSY pin (driver state interface).

  Continuously polls the BUSY pin until it goes LOW, indicating the display
  has finished processing the previous command. Essential for proper timing
  between commands to prevent display corruption.
  """
  defp wait_until_idle_hal(hal, hal_state, timeout_ms \\ 15_000) do
    case wait_until_idle_loop(hal, hal_state, timeout_ms, System.monotonic_time(:millisecond)) do
      {:ok, new_hal_state} ->
        {:ok, new_hal_state}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp wait_until_idle_loop(hal, hal_state, timeout_ms, start_time) do
    current_time = System.monotonic_time(:millisecond)

    if current_time - start_time > timeout_ms do
      Logger.error("Driver: Timeout waiting for idle state",
        timeout_ms: timeout_ms,
        elapsed_ms: current_time - start_time,
        hal_module: hal
      )

      {:error, :timeout}
    else
      case hal.gpio_read_busy(hal_state) do
        {:ok, 0, hal_state} ->
          {:ok, hal_state}

        {:ok, 1, hal_state} ->
          Process.sleep(10)
          wait_until_idle_loop(hal, hal_state, timeout_ms, start_time)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp send_command_hal(hal, hal_state, command) when is_integer(command) do
    # FIXME Instead of gpio_set_dc, we could have a hal.gpio_set_command_mode/1.
    #       And similarly, a hal.gpio_set_data_mode/1.
    #       Or clarify if these helper functions should exist on the driver side.
    with {:ok, hal_state} <- hal.gpio_set_dc(hal_state, 0),
         {:ok, hal_state} <- hal.spi_write(hal_state, <<command>>) do
      {:ok, hal_state}
    end
  end

  defp send_data_hal(hal, hal_state, data) when is_binary(data) do
    with {:ok, hal_state} <- hal.gpio_set_dc(hal_state, 1),
         {:ok, hal_state} <- hal.spi_write(hal_state, data) do
      {:ok, hal_state}
    end
  end

  # Set the memory area for writing.
  defp set_memory_area_hal(hal, hal_state, x_start, y_start, x_end, y_end) do
    with {:ok, hal_state} <-
           send_command_hal(hal, hal_state, @command_set_ram_x_address_start_end_position),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<x_start >>> 3 &&& 0xFF>>),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<x_end >>> 3 &&& 0xFF>>),
         {:ok, hal_state} <-
           send_command_hal(hal, hal_state, @command_set_ram_y_address_start_end_position),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<y_start &&& 0xFF>>),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<y_start >>> 8 &&& 0xFF>>),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<y_end &&& 0xFF>>),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<y_end >>> 8 &&& 0xFF>>) do
      {:ok, hal_state}
    end
  end

  # Set the memory pointer for writing.
  defp set_memory_pointer(hal, hal_state, x, y) do
    with {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_set_ram_x_address_counter),
         # highest 3 bits are ignored
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<x &&& 0xFF>>),
         {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_set_ram_y_address_counter),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<y &&& 0xFF>>),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<y >>> 8 &&& 0xFF>>) do
      {:ok, hal_state}
    end
  end

  @doc """
  Render image data with full display refresh.
  """
  @spec render_image(t(), binary()) :: {:ok, t()} | {:error, :invalid_image_size | term()}
  def render_image(%__MODULE__{} = driver_state, image_data) when is_binary(image_data) do
    %{hal_module: hal, hal_state: hal_state} = driver_state

    case render_image_hal(hal, hal_state, image_data) do
      {:ok, new_hal_state} ->
        {:ok, %{driver_state | hal_state: new_hal_state}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp render_image_hal(hal, hal_state, image_data) when is_binary(image_data) do
    Logger.debug(
      "Driver: Drawing image with full display refresh - #{byte_size(image_data)} bytes"
    )

    expected_size = div(@width, 8) * @height

    # FIXME Can't this be handled by proper typing?
    if byte_size(image_data) != expected_size do
      Logger.error(
        "Driver: Invalid image data size. Expected #{expected_size}, got #{byte_size(image_data)}"
      )

      {:error, :invalid_image_size}
    else
      with {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_write_ram),
           {:ok, hal_state} <- send_data_hal(hal, hal_state, image_data),
           {:ok, hal_state} <- turn_on_display_hal(hal, hal_state) do
        Logger.debug("Driver: Completed image rendering with full refresh")
        {:ok, hal_state}
      end
    end
  end

  @doc """
  Display image data using partial display update.
  """
  @spec render_image_partial(t(), binary()) ::
          {:ok, t()} | {:error, :invalid_image_size | term()}
  def render_image_partial(%__MODULE__{} = driver_state, image_data)
      when is_binary(image_data) do
    %{hal_module: hal, hal_state: hal_state} = driver_state

    case render_image_partial_hal(hal, hal_state, image_data) do
      {:ok, new_hal_state} ->
        {:ok, %{driver_state | hal_state: new_hal_state}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp render_image_partial_hal(hal, hal_state, image_data) when is_binary(image_data) do
    Logger.debug(
      "Driver: Drawing image with partial display refresh - #{byte_size(image_data)} bytes"
    )

    expected_size = div(@width, 8) * @height

    if byte_size(image_data) != expected_size do
      Logger.error(
        "Driver: Invalid image data size. Expected #{expected_size}, got #{byte_size(image_data)}"
      )

      {:error, :invalid_image_size}
    else
      with {:ok, hal_state} <- hal.gpio_set_rst(hal_state, 0),
           :ok <- hal.sleep(2),
           {:ok, hal_state} <- hal.gpio_set_rst(hal_state, 1),
           :ok <- hal.sleep(2),
           # ...
           {:ok, hal_state} <- set_lut(hal, hal_state, LookUpTables.wf_partial()),
           {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_partial_update),
           {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x00>>),
           {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x00>>),
           {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x00>>),
           {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x00>>),
           {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x00>>),
           {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x40>>),
           {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x00>>),
           {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x00>>),
           {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x00>>),
           {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x00>>),
           # ...
           {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_border_waveform_control),
           {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x80>>),
           # ...
           {:ok, hal_state} <-
             send_command_hal(hal, hal_state, @command_display_update_control_2),
           {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0xC0>>),
           {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_master_activation),
           {:ok, hal_state} <- wait_until_idle_hal(hal, hal_state),
           # ...
           {:ok, hal_state} <- set_memory_area_hal(hal, hal_state, 0, 0, @width - 1, @height - 1),
           {:ok, hal_state} <- set_memory_pointer(hal, hal_state, 0, 0),
           # ...
           {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_write_ram_bw),
           {:ok, hal_state} <- send_data_hal(hal, hal_state, image_data),
           {:ok, hal_state} <- turn_on_display_partial_hal(hal, hal_state) do
        Logger.debug("Driver: Completed image rendering with partial refresh")
        {:ok, hal_state}
      end
    end
  end

  @doc """
  Clear display with specified image data (new driver state interface).
  """
  @spec clear(t(), binary()) :: {:ok, t()} | {:error, term()}
  def clear(%__MODULE__{} = driver_state, image_data) when is_binary(image_data) do
    %{hal_module: hal, hal_state: hal_state} = driver_state

    case clear_hal(hal, hal_state, image_data) do
      {:ok, new_hal_state} ->
        {:ok, %{driver_state | hal_state: new_hal_state}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp clear_hal(hal, hal_state, image_data) when is_binary(image_data) do
    Logger.debug("Driver: clearing display")

    with {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_write_ram_bw),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, image_data),
         {:ok, hal_state} <- turn_on_display_hal(hal, hal_state),
         {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_write_ram_red),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, image_data),
         {:ok, hal_state} <- turn_on_display_hal(hal, hal_state) do
      Logger.debug("Driver: Full frame refresh complete")
      {:ok, hal_state}
    end
  end

  defp turn_on_display_hal(hal, hal_state) do
    with {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_display_update_control_2),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0xC7>>),
         {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_master_activation),
         {:ok, hal_state} <- wait_until_idle_hal(hal, hal_state) do
      Logger.debug("Driver: Turned display on")
      {:ok, hal_state}
    end
  end

  defp turn_on_display_partial_hal(hal, hal_state) do
    with {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_display_update_control_2),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<0x0F>>),
         {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_master_activation),
         {:ok, hal_state} <- wait_until_idle_hal(hal, hal_state) do
      Logger.debug("Driver: Turned display on (partially)")
      {:ok, hal_state}
    end
  end

  @spec set_lut(module(), t(), binary()) :: {:ok, t()} | {:error, term()}
  defp set_lut(hal, hal_state, lut) do
    Logger.debug("Driver: Setting LUT")

    # Convert to list for easy indexed access
    lut_bytes = :binary.bin_to_list(lut)

    with {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_write_lut_register),
         {:ok, hal_state} <- send_lut_bytes_individually(hal, hal_state, lut_bytes, 0, 152),
         {:ok, hal_state} <- wait_until_idle_hal(hal, hal_state),
         {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_lut_end_option),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<Enum.at(lut_bytes, 153)>>),
         {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_gate_voltage),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<Enum.at(lut_bytes, 154)>>),
         {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_source_voltage),
         # VSH
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<Enum.at(lut_bytes, 155)>>),
         # VSH2
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<Enum.at(lut_bytes, 156)>>),
         # VSL
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<Enum.at(lut_bytes, 157)>>),
         {:ok, hal_state} <- send_command_hal(hal, hal_state, @command_write_vcom_register),
         {:ok, hal_state} <- send_data_hal(hal, hal_state, <<Enum.at(lut_bytes, 158)>>) do
      {:ok, hal_state}
    end
  end

  # Helper function to send LUT bytes individually (matching Python for loop)
  defp send_lut_bytes_individually(_hal, hal_state, _lut_bytes, index, max_index)
       when index > max_index do
    {:ok, hal_state}
  end

  defp send_lut_bytes_individually(hal, hal_state, lut_bytes, index, max_index) do
    with {:ok, hal_state} <- send_data_hal(hal, hal_state, <<Enum.at(lut_bytes, index)>>) do
      send_lut_bytes_individually(hal, hal_state, lut_bytes, index + 1, max_index)
    end
  end
end
