defmodule MoodBot.Display.MockHAL do
  @moduledoc """
  Mock Hardware Abstraction Layer for development and testing.

  Implements the HAL behavior with simulated responses and logging
  for development when running on host without actual hardware.
  """

  @behaviour MoodBot.Display.HAL

  require Logger

  defstruct [
    :config,
    dc_state: 0,
    rst_state: 1,
    busy_state: 0
  ]

  @impl true
  def init(config) do
    Logger.debug("Initializing MockHAL with config: #{inspect(config)}")

    state = %__MODULE__{
      config: config,
      dc_state: 0,
      rst_state: 1,
      busy_state: 0
    }

    Logger.info("MockHAL initialized for development mode")
    {:ok, state}
  end

  @impl true
  def spi_write(state, data) when is_binary(data) do
    Logger.debug(
      "MockHAL: SPI write #{byte_size(data)} bytes: #{inspect(binary_part(data, 0, min(8, byte_size(data))))}..."
    )

    {:ok, state}
  end

  @impl true
  def gpio_set_dc(state, value) when value in [0, 1] do
    Logger.debug(
      "MockHAL: Set DC pin to #{value} (#{if value == 1, do: "data", else: "command"} mode)"
    )

    new_state = %{state | dc_state: value}
    {:ok, new_state}
  end

  @impl true
  def gpio_set_rst(state, value) when value in [0, 1] do
    Logger.debug(
      "MockHAL: Set RST pin to #{value} (#{if value == 1, do: "inactive", else: "active"})"
    )

    new_state = %{state | rst_state: value}
    {:ok, new_state}
  end

  @impl true
  def gpio_read_busy(state) do
    # Simulate busy pin behavior - randomly return 0 (not busy) most of the time
    busy_value = if :rand.uniform(10) == 1, do: 1, else: 0

    Logger.debug(
      "MockHAL: Read BUSY pin: #{busy_value} (#{if busy_value == 1, do: "busy", else: "ready"})"
    )

    new_state = %{state | busy_state: busy_value}
    {:ok, busy_value, new_state}
  end

  @impl true
  def close(_state) do
    Logger.debug("MockHAL: Closing (no-op for mock)")
    :ok
  end

  @impl true
  def sleep(milliseconds) when is_integer(milliseconds) and milliseconds >= 0 do
    Logger.debug("MockHAL: Sleeping for #{milliseconds}ms")
    Process.sleep(milliseconds)
    :ok
  end
end
