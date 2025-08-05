defmodule MoodBot.Display.HAL do
  @moduledoc """
  Hardware Abstraction Layer (HAL) behavior for e-ink display communication.

  This behavior defines the interface for SPI and GPIO operations needed to
  control the Waveshare 2.9" e-ink display. Different implementations enable
  development without hardware (MockHAL) and production deployment (RpiHAL).

  ## Implementations

  - `MoodBot.Display.MockHAL` - Development simulation with bitmap output
  - `MoodBot.Display.RpiHAL` - Hardware implementation using circuits_gpio/circuits_spi

  ## GPIO Pin Functions

  - **DC (Data/Command)**: Controls whether SPI data is command (0) or data (1)
  - **RST (Reset)**: Hardware reset line (0=active, 1=inactive)
  - **BUSY**: Status pin from display (0=ready, 1=busy processing)
  - **CS (Chip Select)**: SPI chip select (managed internally by implementations)
  - **PWR (Power)**: Power control pin for display module

  ## Configuration

  HAL implementations expect configuration from `config/target.exs` with GPIO
  pins specified as controller/offset tuples per circuits_gpio specification:

      config :mood_bot, MoodBot.Display,
        spi_device: "spidev0.0",
        dc_gpio: {"gpiochip0", 25},
        rst_gpio: {"gpiochip0", 17},
        busy_gpio: {"gpiochip0", 24},
        pwr_gpio: {"gpiochip0", 18}
  """

  @type impl :: module()
  @type hal_state :: term()
  @type gpio_pin_value :: 0 | 1

  @doc """
  Initialize the HAL with the given configuration.

  Configures GPIO pins and SPI interface according to the provided configuration.
  For RpiHAL, this opens actual hardware resources. For MockHAL, this sets up
  simulation state and optional bitmap generation.
  """
  @callback init(config :: map()) :: {:ok, hal_state()} | {:error, term()}

  @doc """
  Send SPI data to the display.

  ## Parameters
  - `state`: HAL state from init/1
  - `data`: Binary data to send via SPI

  Returns `{:ok, state}` on success or `{:error, reason}` on failure.
  """
  @callback spi_write(state :: hal_state(), data :: binary()) ::
              {:ok, hal_state()} | {:error, term()}

  @callback gpio_pwr_on(state :: hal_state()) :: {:ok, hal_state()} | {:error, term()}
  @callback gpio_pwr_off(state :: hal_state()) :: {:ok, hal_state()} | {:error, term()}

  @doc """
  Set the Data/Command (DC) GPIO pin state.

  ## Parameters
  - `state`: HAL state
  - `value`: 0 for command mode, 1 for data mode
  """
  @callback gpio_set_dc(state :: hal_state(), value :: gpio_pin_value()) ::
              {:ok, hal_state()} | {:error, term()}

  @doc """
  Set the Reset (RST) GPIO pin state.

  ## Parameters
  - `state`: HAL state
  - `value`: 0 for reset active, 1 for reset inactive
  """
  @callback gpio_set_rst(state :: hal_state(), value :: gpio_pin_value()) ::
              {:ok, hal_state()} | {:error, term()}

  @doc """
  Read the Busy GPIO pin state.

  Returns the current state of the busy pin (0 or 1).
  """
  @callback gpio_read_busy(state :: hal_state()) ::
              {:ok, gpio_pin_value(), hal_state()} | {:error, term()}

  @doc """
  Cleanup and close HAL resources.
  """
  @callback close(state :: hal_state()) :: :ok

  @doc """
  Sleep for the specified number of milliseconds.

  This is abstracted to allow for different implementations in testing.
  """
  @callback sleep(milliseconds :: non_neg_integer()) :: :ok
end
