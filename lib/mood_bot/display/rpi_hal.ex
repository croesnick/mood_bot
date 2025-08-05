defmodule MoodBot.Display.RpiHAL do
  @moduledoc """
  Raspberry Pi Hardware Abstraction Layer for Waveshare 2.9" e-ink display.

  Implements the HAL behavior using Circuits.GPIO and Circuits.SPI for
  actual hardware communication on Raspberry Pi.
  """

  use TypedStruct

  @behaviour MoodBot.Display.HAL

  alias Circuits.GPIO
  alias Circuits.SPI

  require Logger

  @type config :: %{
          spi_device: String.t(),
          pwr_gpio: Circuits.GPIO.gpio_spec(),
          dc_gpio: Circuits.GPIO.gpio_spec(),
          rst_gpio: Circuits.GPIO.gpio_spec(),
          busy_gpio: Circuits.GPIO.gpio_spec()
        }

  typedstruct do
    field(:spi, term())
    field(:pwr_gpio, Circuits.GPIO.Handle.t())
    field(:dc_gpio, Circuits.GPIO.Handle.t())
    field(:rst_gpio, Circuits.GPIO.Handle.t())
    field(:busy_gpio, Circuits.GPIO.Handle.t())
  end

  @impl true
  @doc """
  Partly port of init procedure from the Python driver.

  See:
    - https://github.com/waveshareteam/e-Paper/blob/master/RaspberryPi_JetsonNano/python/lib/waveshare_epd/epd2in9_V2.py#L228
    - https://github.com/waveshareteam/e-Paper/blob/master/RaspberryPi_JetsonNano/python/lib/waveshare_epd/epdconfig.py#L116
  """
  @spec init(config()) :: {:ok, t()} | {:error, atom()}
  def init(config) do
    Logger.debug("Initializing RpiHAL with config: #{inspect(config)}")

    # Validate configuration before attempting hardware initialization
    with :ok <- validate_spi_device(config.spi_device),
         :ok <- validate_gpio_availability(config),
         {:ok, pwr_gpio} <- GPIO.open(config.pwr_gpio, :output),
         {:ok, dc_gpio} <- GPIO.open(config.dc_gpio, :output),
         {:ok, rst_gpio} <- GPIO.open(config.rst_gpio, :output),
         {:ok, busy_gpio} <- GPIO.open(config.busy_gpio, :input, pull_mode: :pulldown),
         :ok <- GPIO.write(pwr_gpio, 1),
         {:ok, spi} <- SPI.open(config.spi_device, mode: 0, speed_hz: 4_000_000) do
      state = %__MODULE__{
        spi: spi,
        pwr_gpio: pwr_gpio,
        dc_gpio: dc_gpio,
        rst_gpio: rst_gpio,
        busy_gpio: busy_gpio
      }

      Logger.debug("RpiHAL initialized successfully")
      {:ok, state}
    else
      {:error, reason} ->
        Logger.error("Failed to initialize RpiHAL",
          error: reason,
          config: config,
          spi_device: config.spi_device,
          gpio_pins: [
            pwr: config.pwr_gpio,
            dc: config.dc_gpio,
            rst: config.rst_gpio,
            busy: config.busy_gpio
          ]
        )

        {:error, {:hal_init_failed, reason}}
    end
  end

  @impl true
  def spi_write(state, data) when is_binary(data) do
    # Split large transfers into chunks to avoid SPI driver limits
    # Use dynamic chunk size based on SPI driver capabilities, with fallback to tested safe size
    chunk_size = min(SPI.max_transfer_size(state.spi), 4000)

    if byte_size(data) <= chunk_size do
      spi_write_chunk(state, data)
    else
      spi_write_chunked(state, data, chunk_size)
    end
  end

  defp spi_write_chunk(state, data) do
    Logger.debug("SPI: Writing chunk of #{byte_size(data)} bytes")

    case SPI.transfer(state.spi, data) do
      {:ok, _response} ->
        {:ok, state}

      {:error, reason} ->
        Logger.error("SPI write failed",
          error: reason,
          data_size: byte_size(data)
        )

        {:error, {:spi_write_failed, reason}}
    end
  end

  defp spi_write_chunked(state, data, _chunk_size) do
    Logger.debug("SPI: Chunked write of #{byte_size(data)} bytes in chunks")

    result = spi_write_chunks(state, data, min(SPI.max_transfer_size(state.spi), 4000), 0)

    # Post-transfer settling delay to allow display controller to process complete transfer
    case result do
      {:ok, hal_state} ->
        # Give controller time to settle after chunked transfer
        Process.sleep(50)
        {:ok, hal_state}

      error ->
        error
    end
  end

  defp spi_write_chunks(state, data, chunk_size, offset) when offset >= byte_size(data) do
    {:ok, state}
  end

  defp spi_write_chunks(state, data, chunk_size, offset) do
    remaining = byte_size(data) - offset
    current_chunk_size = min(chunk_size, remaining)

    chunk = binary_part(data, offset, current_chunk_size)

    case SPI.transfer(state.spi, chunk) do
      {:ok, _response} ->
        # No delay between chunks for continuous transfer
        spi_write_chunks(state, data, chunk_size, offset + current_chunk_size)

      {:error, reason} ->
        Logger.error("SPI chunked write failed",
          error: reason,
          offset: offset,
          chunk_size: current_chunk_size,
          total_size: byte_size(data),
          remaining: byte_size(data) - offset
        )

        {:error, {:spi_chunked_write_failed, reason}}
    end
  end

  @impl true
  def gpio_pwr_on(state), do: gpio_set_pwr(state, 1)

  @impl true
  def gpio_pwr_off(state), do: gpio_set_pwr(state, 0)

  defp gpio_set_pwr(state, value) when value in [0, 1] do
    case GPIO.write(state.pwr_gpio, value) do
      :ok ->
        {:ok, state}

      {:error, reason} ->
        Logger.error("GPIO power<-#{value} failed",
          error: reason,
          gpio_pin: "pwr"
        )

        {:error, {:gpio_power_on_failed, reason}}
    end
  end

  @impl true
  def gpio_set_dc(state, value) when value in [0, 1] do
    case GPIO.write(state.dc_gpio, value) do
      :ok ->
        {:ok, state}

      {:error, reason} ->
        Logger.error("GPIO set DC failed",
          error: reason,
          value: value,
          gpio_pin: "dc"
        )

        {:error, {:gpio_set_dc_failed, reason}}
    end
  end

  @impl true
  def gpio_set_rst(state, value) when value in [0, 1] do
    case GPIO.write(state.rst_gpio, value) do
      :ok ->
        {:ok, state}

      {:error, reason} ->
        Logger.error("GPIO set RST failed",
          error: reason,
          value: value,
          gpio_pin: "rst"
        )

        {:error, {:gpio_set_rst_failed, reason}}
    end
  end

  @impl true
  def gpio_read_busy(state) do
    try do
      value = GPIO.read(state.busy_gpio)
      {:ok, value, state}
    rescue
      error ->
        Logger.error("GPIO read BUSY failed",
          error: error,
          gpio_pin: "busy"
        )

        {:error, {:gpio_read_busy_failed, error}}
    end
  end

  @impl true
  def close(state) do
    Logger.debug("Closing RpiHAL resources")
    SPI.close(state.spi)

    GPIO.close(state.dc_gpio)
    GPIO.close(state.rst_gpio)
    GPIO.close(state.busy_gpio)

    GPIO.close(state.pwr_gpio)

    :ok
  end

  @impl true
  def sleep(milliseconds) when is_integer(milliseconds) and milliseconds >= 0 do
    # FIXME Is this the most correct and Elixir idiomatic way?
    Process.sleep(milliseconds)
    :ok
  end

  # Configuration validation functions

  defp validate_spi_device(spi_device) do
    spi_path = "/dev/#{spi_device}"

    if File.exists?(spi_path) do
      case File.stat(spi_path) do
        {:ok, %{type: :device}} ->
          Logger.debug("SPI device validated: #{spi_path}")
          :ok

        {:ok, %{type: other_type}} ->
          Logger.error(
            "SPI device validation failed: #{spi_path} is not a device file (type: #{other_type})"
          )

          {:error, {:invalid_spi_device_type, spi_device, other_type}}

        {:error, reason} ->
          Logger.error("SPI device validation failed: cannot stat #{spi_path}", error: reason)
          {:error, {:spi_device_stat_failed, spi_device, reason}}
      end
    else
      Logger.error("SPI device validation failed: #{spi_path} does not exist")
      {:error, {:spi_device_not_found, spi_device}}
    end
  end

  defp validate_gpio_availability(config) do
    gpio_pins = [
      {:pwr_gpio, config.pwr_gpio},
      {:dc_gpio, config.dc_gpio},
      {:rst_gpio, config.rst_gpio},
      {:busy_gpio, config.busy_gpio}
    ]

    Enum.reduce_while(gpio_pins, :ok, fn {name, gpio_spec}, _acc ->
      case validate_single_gpio(name, gpio_spec) do
        :ok -> {:cont, :ok}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp validate_single_gpio(name, {controller, offset})
       when is_binary(controller) and is_integer(offset) do
    # Use modern GPIO validation through Circuits.GPIO
    case Circuits.GPIO.enumerate()
         |> Enum.find(fn %{location: {chip, pin}} ->
           chip == controller and pin == offset
         end) do
      %{location: {^controller, ^offset}} ->
        Logger.debug("GPIO validated: #{name} -> {#{controller}, #{offset}}")
        :ok

      nil ->
        Logger.error(
          "GPIO validation failed: #{name} pin {#{controller}, #{offset}} not found in GPIO enumeration"
        )

        {:error, {:gpio_pin_not_found, name, {controller, offset}}}
    end
  end

  defp validate_single_gpio(name, pin_number) when is_integer(pin_number) and pin_number >= 0 do
    # Legacy pin number format - use Circuits.GPIO to validate
    case Circuits.GPIO.enumerate()
         |> Enum.find(fn %{location: {_chip, pin}} ->
           pin == pin_number
         end) do
      %{location: {_chip, ^pin_number}} ->
        Logger.debug("GPIO validated: #{name} -> #{pin_number} (legacy format)")
        :ok

      nil ->
        Logger.error(
          "GPIO validation failed: #{name} pin #{pin_number} not found in GPIO enumeration"
        )

        {:error, {:gpio_pin_not_found, name, pin_number}}
    end
  end

  defp validate_single_gpio(name, invalid_spec) do
    Logger.error("GPIO validation failed: #{name} invalid GPIO specification",
      gpio_spec: invalid_spec
    )

    {:error, {:gpio_invalid_specification, name, invalid_spec}}
  end
end
