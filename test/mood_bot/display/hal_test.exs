defmodule MoodBot.Display.HALTest do
  use ExUnit.Case, async: true

  alias MoodBot.Display.HAL
  alias MoodBot.DisplayTestHelper.TestHAL

  describe "HAL behavior" do
    test "TestHAL implements all required callbacks" do
      # Verify that TestHAL implements the HAL behavior correctly
      assert function_exported?(TestHAL, :init, 1)
      assert function_exported?(TestHAL, :spi_write, 2)
      assert function_exported?(TestHAL, :gpio_set_dc, 2)
      assert function_exported?(TestHAL, :gpio_set_rst, 2)
      assert function_exported?(TestHAL, :gpio_read_busy, 1)
      assert function_exported?(TestHAL, :close, 1)
      assert function_exported?(TestHAL, :sleep, 1)
    end

    test "HAL behavior defines all required callbacks" do
      # Check that the behavior defines the expected callbacks
      callbacks = HAL.behaviour_info(:callbacks)

      expected_callbacks = [
        init: 1,
        spi_write: 2,
        gpio_set_dc: 2,
        gpio_set_rst: 2,
        gpio_read_busy: 1,
        close: 1,
        sleep: 1
      ]

      for callback <- expected_callbacks do
        assert callback in callbacks, "Missing callback: #{inspect(callback)}"
      end
    end
  end

  describe "TestHAL implementation" do
    setup do
      config = %{test: true}
      {:ok, hal_state} = TestHAL.init(config)

      on_exit(fn ->
        if Process.alive?(hal_state) do
          TestHAL.close(hal_state)
        end
      end)

      %{hal_state: hal_state, config: config}
    end

    test "init/1 records initialization call", %{hal_state: hal_state, config: config} do
      calls = MoodBot.DisplayTestHelper.get_calls(hal_state)
      assert [{:init, ^config}] = calls
    end

    test "spi_write/2 records SPI write calls", %{hal_state: hal_state} do
      data = <<1, 2, 3, 4>>
      assert {:ok, ^hal_state} = TestHAL.spi_write(hal_state, data)

      calls = MoodBot.DisplayTestHelper.get_calls(hal_state)
      assert Enum.any?(calls, fn call -> call == {:spi_write, 4} end)
    end

    test "gpio_set_dc/2 records DC pin state changes", %{hal_state: hal_state} do
      assert {:ok, ^hal_state} = TestHAL.gpio_set_dc(hal_state, 1)
      assert {:ok, ^hal_state} = TestHAL.gpio_set_dc(hal_state, 0)

      calls = MoodBot.DisplayTestHelper.get_calls(hal_state)
      assert Enum.any?(calls, fn call -> call == {:gpio_set_dc, 1} end)
      assert Enum.any?(calls, fn call -> call == {:gpio_set_dc, 0} end)
    end

    test "gpio_set_rst/2 records reset pin state changes", %{hal_state: hal_state} do
      assert {:ok, ^hal_state} = TestHAL.gpio_set_rst(hal_state, 0)
      assert {:ok, ^hal_state} = TestHAL.gpio_set_rst(hal_state, 1)

      calls = MoodBot.DisplayTestHelper.get_calls(hal_state)
      assert Enum.any?(calls, fn call -> call == {:gpio_set_rst, 0} end)
      assert Enum.any?(calls, fn call -> call == {:gpio_set_rst, 1} end)
    end

    test "gpio_read_busy/1 returns not busy by default", %{hal_state: hal_state} do
      assert {:ok, 0, ^hal_state} = TestHAL.gpio_read_busy(hal_state)

      calls = MoodBot.DisplayTestHelper.get_calls(hal_state)
      assert Enum.any?(calls, fn call -> call == :gpio_read_busy end)
    end

    test "sleep/1 does not actually sleep in tests" do
      start_time = System.monotonic_time(:millisecond)
      TestHAL.sleep(1000)
      end_time = System.monotonic_time(:millisecond)

      # Should complete almost instantly, not wait 1000ms
      assert end_time - start_time < 100
      assert Process.get(:test_sleep) == 1000
    end

    test "close/1 records close call and stops agent", %{hal_state: hal_state} do
      assert :ok = TestHAL.close(hal_state)

      # Agent should be stopped after close
      refute Process.alive?(hal_state)
    end
  end
end
