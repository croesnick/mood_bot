defmodule MoodBot.Display.RpiHAL do
  @moduledoc """
  Raspberry Pi Hardware Abstraction Layer for Waveshare 2.9" e-ink display.

  Implements the HAL behavior using Circuits.GPIO and Circuits.SPI for
  actual hardware communication on Raspberry Pi.
  """

  @behaviour MoodBot.Display.HAL

  alias Circuits.GPIO
  alias Circuits.SPI

  require Logger

  defstruct [
    :spi_ref,
    :dc_ref,
    :rst_ref,
    :busy_ref,
    :cs_ref
  ]

  @impl true
  def init(config) do
    Logger.debug("Initializing RpiHAL with config: #{inspect(config)}")

    with {:ok, spi_ref} <- SPI.open(config.spi_device),
         {:ok, dc_ref} <- GPIO.open(config.dc_pin, :output),
         {:ok, rst_ref} <- GPIO.open(config.rst_pin, :output),
         {:ok, busy_ref} <- GPIO.open(config.busy_pin, :input),
         {:ok, cs_ref} <- GPIO.open(config.cs_pin, :output) do
      # Set initial pin states
      # CS high (inactive)
      GPIO.write(cs_ref, 1)
      # RST high (inactive)
      GPIO.write(rst_ref, 1)
      # DC low (command mode)
      GPIO.write(dc_ref, 0)

      state = %__MODULE__{
        spi_ref: spi_ref,
        dc_ref: dc_ref,
        rst_ref: rst_ref,
        busy_ref: busy_ref,
        cs_ref: cs_ref
      }

      Logger.debug("RpiHAL initialized successfully")
      {:ok, state}
    else
      {:error, reason} = error ->
        Logger.error("Failed to initialize RpiHAL: #{inspect(reason)}")
        error
    end
  end

  @impl true
  def spi_write(state, data) when is_binary(data) do
    # Pull CS low, send data, pull CS high
    GPIO.write(state.cs_ref, 0)
    result = SPI.transfer(state.spi_ref, data)
    GPIO.write(state.cs_ref, 1)

    case result do
      {:ok, _response} ->
        {:ok, state}

      {:error, reason} = error ->
        Logger.error("SPI write failed: #{inspect(reason)}")
        error
    end
  end

  @impl true
  def gpio_set_dc(state, value) when value in [0, 1] do
    case GPIO.write(state.dc_ref, value) do
      :ok ->
        {:ok, state}

      {:error, reason} = error ->
        Logger.error("GPIO set DC failed: #{inspect(reason)}")
        error
    end
  end

  @impl true
  def gpio_set_rst(state, value) when value in [0, 1] do
    case GPIO.write(state.rst_ref, value) do
      :ok ->
        {:ok, state}

      {:error, reason} = error ->
        Logger.error("GPIO set RST failed: #{inspect(reason)}")
        error
    end
  end

  @impl true
  def gpio_read_busy(state) do
    case GPIO.read(state.busy_ref) do
      {:ok, value} ->
        {:ok, value, state}

      {:error, reason} = error ->
        Logger.error("GPIO read BUSY failed: #{inspect(reason)}")
        error
    end
  end

  @impl true
  def close(state) do
    Logger.debug("Closing RpiHAL resources")

    # Close all GPIO references
    GPIO.close(state.dc_ref)
    GPIO.close(state.rst_ref)
    GPIO.close(state.busy_ref)
    GPIO.close(state.cs_ref)

    # Close SPI reference
    SPI.close(state.spi_ref)

    :ok
  end

  @impl true
  def sleep(milliseconds) when is_integer(milliseconds) and milliseconds >= 0 do
    Process.sleep(milliseconds)
    :ok
  end
end
