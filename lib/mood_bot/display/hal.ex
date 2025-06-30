defmodule MoodBot.Display.HAL do
  @moduledoc """
  Hardware Abstraction Layer (HAL) behavior for e-ink display communication.

  This behavior defines the interface for SPI and GPIO operations needed to
  control the Waveshare 2.9" e-ink display. Different implementations can
  be used for real hardware vs development/testing.
  """

  @doc """
  Initialize the HAL with the given configuration.

  Returns `{:ok, state}` on success or `{:error, reason}` on failure.
  """
  @callback init(config :: map()) :: {:ok, any()} | {:error, any()}

  @doc """
  Send SPI data to the display.

  ## Parameters
  - `state`: HAL state from init/1
  - `data`: Binary data to send via SPI

  Returns `{:ok, state}` on success or `{:error, reason}` on failure.
  """
  @callback spi_write(state :: any(), data :: binary()) :: {:ok, any()} | {:error, any()}

  @doc """
  Set the Data/Command (DC) GPIO pin state.

  ## Parameters
  - `state`: HAL state
  - `value`: 0 for command mode, 1 for data mode
  """
  @callback gpio_set_dc(state :: any(), value :: 0 | 1) :: {:ok, any()} | {:error, any()}

  @doc """
  Set the Reset (RST) GPIO pin state.

  ## Parameters
  - `state`: HAL state  
  - `value`: 0 for reset active, 1 for reset inactive
  """
  @callback gpio_set_rst(state :: any(), value :: 0 | 1) :: {:ok, any()} | {:error, any()}

  @doc """
  Read the Busy GPIO pin state.

  Returns the current state of the busy pin (0 or 1).
  """
  @callback gpio_read_busy(state :: any()) :: {:ok, 0 | 1, any()} | {:error, any()}

  @doc """
  Cleanup and close HAL resources.
  """
  @callback close(state :: any()) :: :ok

  @doc """
  Sleep for the specified number of milliseconds.

  This is abstracted to allow for different implementations in testing.
  """
  @callback sleep(milliseconds :: non_neg_integer()) :: :ok
end
