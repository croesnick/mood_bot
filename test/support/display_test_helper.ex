defmodule MoodBot.DisplayTestHelper do
  @moduledoc """
  Test helper functions for display-related tests.
  """

  alias MoodBot.Display.Driver

  @doc """
  Creates a simple test HAL implementation that tracks calls.
  """
  def create_test_hal do
    Agent.start_link(fn -> %{calls: [], state: :test_state} end)
  end

  @doc """
  Records a HAL call in the test agent.
  """
  def record_call(agent, call) do
    Agent.update(agent, fn state ->
      %{state | calls: [call | state.calls]}
    end)
  end

  @doc """
  Gets all recorded HAL calls.
  """
  def get_calls(agent) do
    Agent.get(agent, fn state -> Enum.reverse(state.calls) end)
  end

  @doc """
  Gets the test HAL state.
  """
  def get_test_state(agent) do
    Agent.get(agent, fn state -> state.state end)
  end

  @doc """
  Updates the test HAL state.
  """
  def set_test_state(agent, new_state) do
    Agent.update(agent, fn state -> %{state | state: new_state} end)
  end

  @doc """
  Creates test display configuration.
  """
  def test_config do
    %{
      spi_device: "test_spi",
      dc_pin: 99,
      rst_pin: 98,
      busy_pin: 97,
      cs_pin: 96,
      hal_module: MoodBot.DisplayTestHelper.TestHAL
    }
  end

  @doc """
  Creates integration test configuration using MockHAL for realistic behavior.
  """
  def integration_config do
    %{
      spi_device: "test_spi",
      dc_pin: 99,
      rst_pin: 98,
      busy_pin: 97,
      cs_pin: 96,
      hal_module: MoodBot.Display.MockHAL,
      save_bitmaps: true
    }
  end

  @doc """
  Creates a valid test image for the display dimensions.
  """
  def test_image_data do
    {width, height} = Driver.dimensions()
    size = div(width, 8) * height
    # Alternating pattern
    :binary.copy(<<0x55>>, size)
  end

  @doc """
  Validates that a binary is a valid display image.
  """
  def valid_image?(data) when is_binary(data) do
    {width, height} = Driver.dimensions()
    expected_size = div(width, 8) * height
    byte_size(data) == expected_size
  end

  def valid_image?(_), do: false

  defmodule TestHAL do
    @moduledoc """
    A test HAL implementation that records all calls for verification.
    """

    @behaviour MoodBot.Display.HAL

    @impl true
    def init(config) do
      {:ok, agent} = MoodBot.DisplayTestHelper.create_test_hal()
      MoodBot.DisplayTestHelper.record_call(agent, {:init, config})
      {:ok, agent}
    end

    @impl true
    def spi_write(agent, data) do
      MoodBot.DisplayTestHelper.record_call(agent, {:spi_write, byte_size(data)})
      {:ok, agent}
    end

    @impl true
    def gpio_set_dc(agent, value) do
      MoodBot.DisplayTestHelper.record_call(agent, {:gpio_set_dc, value})
      {:ok, agent}
    end

    @impl true
    def gpio_set_rst(agent, value) do
      MoodBot.DisplayTestHelper.record_call(agent, {:gpio_set_rst, value})
      {:ok, agent}
    end

    @impl true
    def gpio_read_busy(agent) do
      MoodBot.DisplayTestHelper.record_call(agent, :gpio_read_busy)
      # Return not busy by default
      {:ok, 0, agent}
    end

    @impl true
    def close(agent) do
      MoodBot.DisplayTestHelper.record_call(agent, :close)
      Agent.stop(agent)
      :ok
    end

    @impl true
    def sleep(milliseconds) do
      # Don't actually sleep in tests
      Process.put(:test_sleep, milliseconds)
      :ok
    end
  end
end
