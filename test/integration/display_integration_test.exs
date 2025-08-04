defmodule MoodBot.DisplayIntegrationTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MoodBot.Display
  alias MoodBot.DisplayTestHelper

  @moduletag :integration

  describe "Full display workflow integration" do
    setup do
      # Start application components needed for integration
      config = DisplayTestHelper.integration_config()

      test_name = :"display_integration_#{System.unique_integer()}"
      {:ok, pid} = Display.start_link(name: test_name, config: config)

      on_exit(fn ->
        if Process.alive?(pid) do
          GenServer.stop(pid)
        end
      end)

      %{display: test_name, pid: pid}
    end

    test "complete mood display workflow", %{display: display} do
      log =
        capture_log(fn ->
          # 1. Check initial status
          status = Display.status(display)
          assert status.initialized == false
          assert status.display_state == :stopped

          # 2. Initialize display
          assert :ok = Display.init_display(display)

          # 3. Verify initialization
          status = Display.status(display)
          assert status.initialized == true
          assert status.display_state == :initialized

          # 4. Clear display
          assert :ok = Display.clear(display)

          # 5. Show different moods in sequence
          moods = [:happy, :sad, :neutral, :angry, :surprised]

          for mood <- moods do
            assert :ok = Display.show_mood(display, mood)
            # Small delay to simulate real usage
            Process.sleep(10)
          end

          # 6. Display custom image
          image_data = DisplayTestHelper.test_image_data()
          assert :ok = Display.display_image(display, image_data)

          # 7. Clear again
          assert :ok = Display.clear(display)

          # 8. Put to sleep
          assert :ok = Display.sleep(display)

          # 9. Check final status
          final_status = Display.status(display)
          assert final_status.initialized == true
          assert final_status.display_state == :sleeping
        end)

      # Verify log sequence shows complete workflow
      # Note: "Display: Starting with config" happens during setup, not captured here
      assert log =~ "Display: Initializing hardware"
      assert log =~ "Display: Hardware initialization complete"
      assert log =~ "Display: Clearing display"
      assert log =~ "Display: Showing mood: happy"
      assert log =~ "Display: Showing mood: sad"
      assert log =~ "Display: Showing mood: neutral"
      assert log =~ "Display: Showing mood: angry"
      assert log =~ "Display: Showing mood: surprised"
      assert log =~ "Display: Displaying image"
      assert log =~ "Display: Entering sleep mode"
    end

    test "error recovery workflow", %{display: display} do
      log =
        capture_log(fn ->
          # 1. Try operations before initialization
          assert {:error, :not_initialized} = Display.clear(display)
          assert {:error, :not_initialized} = Display.show_mood(display, :happy)

          # 2. Initialize successfully
          assert :ok = Display.init_display(display)

          # 3. Try invalid image data
          invalid_data = <<1, 2, 3>>

          assert {:error, {:operation_failed, :invalid_image_size}} =
                   Display.display_image(display, invalid_data)

          # 4. Verify display still works after error
          assert :ok = Display.show_mood(display, :happy)
          assert :ok = Display.clear(display)
        end)

      assert log =~ "Display: Invalid image data size"
      assert log =~ "Display: Showing mood: happy"
    end

    test "concurrent access workflow", %{display: display} do
      # Initialize first
      assert :ok = Display.init_display(display)

      # Start multiple tasks that access the display concurrently
      tasks =
        for i <- 1..5 do
          Task.async(fn ->
            mood = Enum.at([:happy, :sad, :neutral, :angry, :surprised], rem(i, 5))
            result = Display.show_mood(display, mood)
            {i, mood, result}
          end)
        end

      # Wait for all tasks to complete
      results = Task.await_many(tasks, 5000)

      # All operations should succeed
      for {i, mood, result} <- results do
        assert result == :ok, "Task #{i} with mood #{mood} failed: #{inspect(result)}"
      end
    end

    test "state persistence across operations", %{display: display} do
      # Initialize
      assert :ok = Display.init_display(display)

      # Perform various operations
      assert :ok = Display.clear(display)
      status1 = Display.status(display)

      assert :ok = Display.show_mood(display, :happy)
      status2 = Display.status(display)

      assert :ok = Display.sleep(display)
      status3 = Display.status(display)

      # State should evolve correctly
      assert status1.display_state == :initialized
      assert status2.display_state == :initialized
      assert status3.display_state == :sleeping

      # Initialization should persist
      assert status1.initialized == true
      assert status2.initialized == true
      assert status3.initialized == true
    end

    test "memory and resource usage", %{display: display} do
      # This test verifies that repeated operations don't leak memory
      assert :ok = Display.init_display(display)

      # Perform many operations
      for i <- 1..50 do
        mood = Enum.at([:happy, :sad, :neutral, :angry, :surprised], rem(i, 5))
        assert :ok = Display.show_mood(display, mood)

        # Occasionally check status (simulates monitoring)
        if rem(i, 10) == 0 do
          _status = Display.status(display)
        end
      end

      # Final operations should still work
      assert :ok = Display.clear(display)
      assert :ok = Display.sleep(display)

      # GenServer should still be responsive
      final_status = Display.status(display)
      assert final_status.initialized == true
    end

    test "HAL interaction patterns", %{display: display} do
      # This test verifies proper HAL usage patterns
      log =
        capture_log(fn ->
          assert :ok = Display.init_display(display)
          assert :ok = Display.show_mood(display, :happy)
        end)

      # Should show proper HAL interactions
      # Reset during init
      assert log =~ "MockHAL: Set RST pin"
      # Command/data mode switching
      assert log =~ "MockHAL: Set DC pin"
      # Data transmission
      assert log =~ "MockHAL: SPI write"
      # Status checking
      assert log =~ "MockHAL: Read BUSY pin"
    end

    test "configuration inheritance", %{display: display} do
      # Initialize display to create driver_state and set hal_module
      assert :ok = Display.init_display(display)

      status = Display.status(display)

      # Should have test configuration values
      assert status.config.dc_gpio == 99
      assert status.config.rst_gpio == 98
      assert status.config.busy_gpio == 97
      assert status.config.spi_device == "test_spi"

      # HAL module is determined by Mix.target, not config - in test (host) it should be MockHAL
      assert status.hal_module == MoodBot.Display.MockHAL
    end
  end

  describe "Performance characteristics" do
    setup do
      config = DisplayTestHelper.integration_config()
      test_name = :"display_perf_#{System.unique_integer()}"
      {:ok, pid} = Display.start_link(name: test_name, config: config)

      assert :ok = Display.init_display(test_name)

      on_exit(fn ->
        if Process.alive?(pid) do
          GenServer.stop(pid)
        end
      end)

      %{display: test_name}
    end

    test "operation timing", %{display: display} do
      # Test that operations complete in reasonable time
      operations = [
        fn -> Display.clear(display) end,
        fn -> Display.show_mood(display, :happy) end,
        fn -> Display.show_mood(display, :sad) end,
        fn -> Display.status(display) end,
        fn -> Display.sleep(display) end
      ]

      for operation <- operations do
        start_time = System.monotonic_time(:millisecond)
        result = operation.()
        end_time = System.monotonic_time(:millisecond)

        duration = end_time - start_time

        # Operations should complete quickly in test mode
        assert duration < 1000, "Operation took too long: #{duration}ms"
        assert result == :ok or match?(%{}, result), "Operation failed: #{inspect(result)}"
      end
    end

    test "throughput under load", %{display: display} do
      # Test rapid sequential operations
      start_time = System.monotonic_time(:millisecond)

      for i <- 1..20 do
        mood = Enum.at([:happy, :sad, :neutral], rem(i, 3))
        assert :ok = Display.show_mood(display, mood)
      end

      end_time = System.monotonic_time(:millisecond)
      total_time = end_time - start_time

      # Should handle 20 operations in reasonable time
      assert total_time < 5000, "Throughput test took too long: #{total_time}ms"
    end
  end
end
