defmodule MoodBot.Display.MockHALTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MoodBot.Display.MockHAL

  describe "MockHAL implementation" do
    setup do
      config = %{
        spi_device: "test_spi",
        dc_gpio: 25,
        rst_gpio: 17,
        busy_gpio: 24,
        pwr_gpio: 18
      }

      %{config: config}
    end

    test "init/1 succeeds and logs initialization", %{config: config} do
      log =
        capture_log(fn ->
          assert {:ok, state} = MockHAL.init(config)
          assert %MockHAL{config: ^config} = state
        end)

      assert log =~ "Initializing MockHAL"
      assert log =~ "MockHAL initialized for development mode"
    end

    test "spi_write/2 logs SPI operations", %{config: config} do
      {:ok, state} = MockHAL.init(config)
      data = <<1, 2, 3, 4, 5>>

      log =
        capture_log(fn ->
          assert {:ok, ^state} = MockHAL.spi_write(state, data)
        end)

      assert log =~ "MockHAL: SPI write 5 bytes"
      assert log =~ "<<1, 2, 3, 4, 5>>"
    end

    test "spi_write/2 truncates long data in logs", %{config: config} do
      {:ok, state} = MockHAL.init(config)
      # Create data longer than 8 bytes
      data = :binary.copy(<<0xFF>>, 20)

      log =
        capture_log(fn ->
          assert {:ok, ^state} = MockHAL.spi_write(state, data)
        end)

      assert log =~ "MockHAL: SPI write 20 bytes"
      # Should show only first 8 bytes
      assert log =~ "<<255, 255, 255, 255, 255, 255, 255, 255>>"
    end

    test "gpio_set_dc/2 logs DC pin changes with mode description", %{config: config} do
      {:ok, state} = MockHAL.init(config)

      # Test command mode (0)
      log =
        capture_log(fn ->
          assert {:ok, new_state} = MockHAL.gpio_set_dc(state, 0)
          assert new_state.dc_state == 0
        end)

      assert log =~ "MockHAL: Set DC pin to 0 (command mode)"

      # Test data mode (1)
      log =
        capture_log(fn ->
          assert {:ok, new_state} = MockHAL.gpio_set_dc(state, 1)
          assert new_state.dc_state == 1
        end)

      assert log =~ "MockHAL: Set DC pin to 1 (data mode)"
    end

    test "gpio_set_rst/2 logs reset pin changes with state description", %{config: config} do
      {:ok, state} = MockHAL.init(config)

      # Test reset active (0)
      log =
        capture_log(fn ->
          assert {:ok, new_state} = MockHAL.gpio_set_rst(state, 0)
          assert new_state.rst_state == 0
        end)

      assert log =~ "MockHAL: Set RST pin to 0 (active)"

      # Test reset inactive (1)
      log =
        capture_log(fn ->
          assert {:ok, new_state} = MockHAL.gpio_set_rst(state, 1)
          assert new_state.rst_state == 1
        end)

      assert log =~ "MockHAL: Set RST pin to 1 (inactive)"
    end

    test "gpio_read_busy/1 simulates busy pin behavior", %{config: config} do
      {:ok, state} = MockHAL.init(config)

      # Test multiple reads to see randomness
      results =
        for _ <- 1..20 do
          capture_log(fn ->
            assert {:ok, value, new_state} = MockHAL.gpio_read_busy(state)
            assert value in [0, 1]
            assert new_state.busy_state == value
            value
          end)
        end

      # Should have at least some variation (not all the same)
      unique_results = Enum.uniq(results)
      assert length(unique_results) > 1, "Expected some variation in busy pin simulation"
    end

    test "gpio_read_busy/1 logs busy state descriptions", %{config: config} do
      {:ok, state} = MockHAL.init(config)

      # Run multiple times to catch both states
      for _ <- 1..10 do
        log =
          capture_log(fn ->
            {:ok, value, _} = MockHAL.gpio_read_busy(state)
            value
          end)

        # Check for appropriate state description in log
        assert log =~ "(ready)" or log =~ "(busy)"
      end
    end

    test "close/1 logs closure", %{config: config} do
      {:ok, state} = MockHAL.init(config)

      log =
        capture_log(fn ->
          assert :ok = MockHAL.close(state)
        end)

      assert log =~ "MockHAL: Closing (no-op for mock)"
    end

    test "sleep/1 logs sleep duration and actually sleeps", %{config: _config} do
      start_time = System.monotonic_time(:millisecond)

      log =
        capture_log(fn ->
          # Short sleep for test
          assert :ok = MockHAL.sleep(50)
        end)

      end_time = System.monotonic_time(:millisecond)
      duration = end_time - start_time

      assert log =~ "MockHAL: Sleeping for 50ms"
      # Should actually sleep (allow some variance for test timing)
      assert duration >= 45
    end

    test "state management tracks pin states correctly", %{config: config} do
      {:ok, state} = MockHAL.init(config)

      # Initial state
      assert state.dc_state == 0
      assert state.rst_state == 1
      assert state.busy_state == 0

      # Change DC state
      {:ok, state} = MockHAL.gpio_set_dc(state, 1)
      assert state.dc_state == 1

      # Change RST state
      {:ok, state} = MockHAL.gpio_set_rst(state, 0)
      assert state.rst_state == 0

      # Read busy updates state
      {:ok, busy_value, state} = MockHAL.gpio_read_busy(state)
      assert state.busy_state == busy_value
    end
  end
end
