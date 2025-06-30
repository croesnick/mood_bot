defmodule MoodBot.Display.DriverTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MoodBot.Display.Driver
  alias MoodBot.DisplayTestHelper
  alias MoodBot.DisplayTestHelper.TestHAL

  describe "Driver constants and utilities" do
    test "dimensions/0 returns correct display size" do
      assert {128, 296} = Driver.dimensions()
    end
  end

  describe "Driver command functions" do
    setup do
      config = DisplayTestHelper.test_config()
      {:ok, hal_state} = TestHAL.init(config)

      on_exit(fn ->
        if Process.alive?(hal_state) do
          TestHAL.close(hal_state)
        end
      end)

      %{hal: TestHAL, hal_state: hal_state}
    end

    test "send_command/3 sets DC low and sends command", %{hal: hal, hal_state: hal_state} do
      assert {:ok, new_state} = Driver.send_command(hal, hal_state, 0x12)

      calls = DisplayTestHelper.get_calls(new_state)

      # Should set DC to 0 (command mode) then send 1 byte
      assert Enum.any?(calls, fn call -> call == {:gpio_set_dc, 0} end)
      assert Enum.any?(calls, fn call -> call == {:spi_write, 1} end)
    end

    test "send_data/3 sets DC high and sends data", %{hal: hal, hal_state: hal_state} do
      data = <<0x01, 0x02, 0x03>>
      assert {:ok, new_state} = Driver.send_data(hal, hal_state, data)

      calls = DisplayTestHelper.get_calls(new_state)

      # Should set DC to 1 (data mode) then send 3 bytes
      assert Enum.any?(calls, fn call -> call == {:gpio_set_dc, 1} end)
      assert Enum.any?(calls, fn call -> call == {:spi_write, 3} end)
    end

    test "reset/2 performs proper reset sequence", %{hal: hal, hal_state: hal_state} do
      log =
        capture_log(fn ->
          assert {:ok, new_state} = Driver.reset(hal, hal_state)

          calls = DisplayTestHelper.get_calls(new_state)

          # Should set RST high, then low, then high again
          rst_calls =
            Enum.filter(calls, fn
              {:gpio_set_rst, _} -> true
              _ -> false
            end)

          assert length(rst_calls) == 3
          assert [{:gpio_set_rst, 1}, {:gpio_set_rst, 0}, {:gpio_set_rst, 1}] = rst_calls
        end)

      assert log =~ "Display: Hardware reset"
    end

    test "wait_until_idle/2 waits for busy pin to go low", %{hal: hal, hal_state: hal_state} do
      log =
        capture_log(fn ->
          assert {:ok, new_state} = Driver.wait_until_idle(hal, hal_state)

          calls = DisplayTestHelper.get_calls(new_state)

          # Should read busy pin at least once
          assert Enum.any?(calls, fn call -> call == :gpio_read_busy end)
        end)

      assert log =~ "Display: Waiting until idle"
      assert log =~ "Display: Ready (idle)"
    end

    test "wait_until_idle/3 respects timeout", %{hal: hal, hal_state: hal_state} do
      # This test would need a modified HAL that always returns busy
      # For now, just test that the function accepts a timeout parameter
      assert {:ok, _} = Driver.wait_until_idle(hal, hal_state, 1000)
    end

    test "set_memory_area/6 sends correct commands", %{hal: hal, hal_state: hal_state} do
      assert {:ok, new_state} = Driver.set_memory_area(hal, hal_state, 0, 0, 127, 295)

      calls = DisplayTestHelper.get_calls(new_state)

      # Should send X address command and Y address command
      command_calls =
        Enum.filter(calls, fn
          {:gpio_set_dc, 0} -> true
          _ -> false
        end)

      # At least 2 commands (X and Y address setup)
      assert length(command_calls) >= 2
    end

    test "set_memory_pointer/4 sets RAM address counters", %{hal: hal, hal_state: hal_state} do
      assert {:ok, new_state} = Driver.set_memory_pointer(hal, hal_state, 0, 0)

      calls = DisplayTestHelper.get_calls(new_state)

      # Should send X counter and Y counter commands
      command_calls =
        Enum.filter(calls, fn
          {:gpio_set_dc, 0} -> true
          _ -> false
        end)

      # At least 2 commands (X and Y counter setup)
      assert length(command_calls) >= 2
    end

    test "display_frame/3 validates image size", %{hal: hal, hal_state: hal_state} do
      # Test with invalid size
      invalid_data = <<1, 2, 3>>

      log =
        capture_log(fn ->
          assert {:error, :invalid_image_size} =
                   Driver.display_frame(hal, hal_state, invalid_data)
        end)

      assert log =~ "Display: Invalid image data size"
    end

    test "display_frame/3 sends valid image data", %{hal: hal, hal_state: hal_state} do
      image_data = DisplayTestHelper.test_image_data()

      log =
        capture_log(fn ->
          assert {:ok, new_state} = Driver.display_frame(hal, hal_state, image_data)

          calls = DisplayTestHelper.get_calls(new_state)

          # Should send the image data
          data_size = byte_size(image_data)
          assert Enum.any?(calls, fn call -> call == {:spi_write, data_size} end)
        end)

      assert log =~ "Display: Updating frame"
      assert log =~ "Display: Frame update complete"
    end

    test "clear/2 creates white image and displays it", %{hal: hal, hal_state: hal_state} do
      log =
        capture_log(fn ->
          assert {:ok, new_state} = Driver.clear(hal, hal_state)

          calls = DisplayTestHelper.get_calls(new_state)

          # Should send image data of the correct size
          {width, height} = Driver.dimensions()
          expected_size = div(width, 8) * height
          assert Enum.any?(calls, fn call -> call == {:spi_write, expected_size} end)
        end)

      assert log =~ "Display: Clearing to white"
    end

    test "turn_on_display/2 sends display update commands", %{hal: hal, hal_state: hal_state} do
      assert {:ok, new_state} = Driver.turn_on_display(hal, hal_state)

      calls = DisplayTestHelper.get_calls(new_state)

      # Should send multiple commands for display update
      command_calls =
        Enum.filter(calls, fn
          {:gpio_set_dc, 0} -> true
          _ -> false
        end)

      # At least a few commands for the update sequence
      assert length(command_calls) >= 3
    end

    test "sleep/2 sends sleep command", %{hal: hal, hal_state: hal_state} do
      log =
        capture_log(fn ->
          assert {:ok, new_state} = Driver.sleep(hal, hal_state)

          calls = DisplayTestHelper.get_calls(new_state)

          # Should send at least one command
          command_calls =
            Enum.filter(calls, fn
              {:gpio_set_dc, 0} -> true
              _ -> false
            end)

          assert length(command_calls) >= 1
        end)

      assert log =~ "Display: Entering sleep mode"
    end
  end

  describe "Driver initialization sequence" do
    setup do
      config = DisplayTestHelper.test_config()
      {:ok, hal_state} = TestHAL.init(config)

      on_exit(fn ->
        if Process.alive?(hal_state) do
          TestHAL.close(hal_state)
        end
      end)

      %{hal: TestHAL, hal_state: hal_state}
    end

    test "init/2 performs complete initialization sequence", %{hal: hal, hal_state: hal_state} do
      log =
        capture_log(fn ->
          assert {:ok, new_state} = Driver.init(hal, hal_state)

          calls = DisplayTestHelper.get_calls(new_state)

          # Should perform reset, send multiple commands, and wait for idle
          # Reset active
          assert Enum.any?(calls, fn call -> call == {:gpio_set_rst, 0} end)
          # Reset inactive
          assert Enum.any?(calls, fn call -> call == {:gpio_set_rst, 1} end)
          # Wait for idle
          assert Enum.any?(calls, fn call -> call == :gpio_read_busy end)

          # Should send several initialization commands
          command_calls =
            Enum.filter(calls, fn
              {:gpio_set_dc, 0} -> true
              _ -> false
            end)

          # Multiple init commands
          assert length(command_calls) >= 5
        end)

      assert log =~ "Display: Initializing Waveshare 2.9"
      assert log =~ "Display: Initialization complete"
    end
  end
end
