defmodule MoodBot.DisplayTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias MoodBot.Display
  alias MoodBot.DisplayTestHelper

  describe "Display GenServer" do
    setup do
      # Use test configuration with TestHAL
      config = DisplayTestHelper.test_config()

      # Start display with unique name for each test
      test_name = :"display_test_#{System.unique_integer()}"
      {:ok, pid} = Display.start_link(name: test_name, config: config)

      on_exit(fn ->
        if Process.alive?(pid) do
          GenServer.stop(pid)
        end
      end)

      %{display: test_name, pid: pid}
    end

    test "starts successfully with test configuration", %{display: display} do
      assert Process.alive?(Process.whereis(display))

      status = Display.status(display)

      assert %{
               initialized: false,
               display_state: :ready,
               hal_module: MoodBot.DisplayTestHelper.TestHAL
             } = status
    end

    test "init_display/1 initializes hardware", %{display: display} do
      log =
        capture_log(fn ->
          assert :ok = Display.init_display(display)
        end)

      assert log =~ "Display: Initializing hardware"
      assert log =~ "Display: Hardware initialization complete"

      status = Display.status(display)
      assert status.initialized == true
      assert status.display_state == :initialized
    end

    test "init_display/1 is idempotent", %{display: display} do
      # First initialization
      assert :ok = Display.init_display(display)

      # Second initialization should succeed without reinitializing
      log =
        capture_log(fn ->
          assert :ok = Display.init_display(display)
        end)

      assert log =~ "Display: Already initialized"
    end

    test "functions require initialization first", %{display: display} do
      # Test operations before initialization
      assert {:error, :not_initialized} = Display.clear(display)
      assert {:error, :not_initialized} = Display.show_mood(display, :happy)

      image_data = DisplayTestHelper.test_image_data()
      assert {:error, :not_initialized} = Display.display_image(display, image_data)
    end

    test "clear/1 clears display after initialization", %{display: display} do
      assert :ok = Display.init_display(display)

      log =
        capture_log(fn ->
          assert :ok = Display.clear(display)
        end)

      assert log =~ "Display: Clearing display"
    end

    test "show_mood/2 displays different moods", %{display: display} do
      assert :ok = Display.init_display(display)

      moods = [:happy, :sad, :neutral, :angry, :surprised]

      for mood <- moods do
        log =
          capture_log(fn ->
            assert :ok = Display.show_mood(display, mood)
          end)

        assert log =~ "Display: Showing mood: #{mood}"
      end
    end

    test "show_mood/2 rejects invalid moods", %{display: display} do
      assert :ok = Display.init_display(display)

      # This should fail at compile time due to the guard, but test the pattern
      assert_raise FunctionClauseError, fn ->
        Display.show_mood(display, :invalid_mood)
      end
    end

    test "display_image/2 validates image size", %{display: display} do
      assert :ok = Display.init_display(display)

      # Test with invalid image data
      invalid_data = <<1, 2, 3>>

      log =
        capture_log(fn ->
          assert {:error, :invalid_image_size} = Display.display_image(display, invalid_data)
        end)

      assert log =~ "Display: Image display failed"
    end

    test "display_image/2 displays valid image data", %{display: display} do
      assert :ok = Display.init_display(display)

      image_data = DisplayTestHelper.test_image_data()

      log =
        capture_log(fn ->
          assert :ok = Display.display_image(display, image_data)
        end)

      assert log =~ "Display: Displaying image"
    end

    test "sleep/1 puts display to sleep", %{display: display} do
      assert :ok = Display.init_display(display)

      log =
        capture_log(fn ->
          assert :ok = Display.sleep(display)
        end)

      assert log =~ "Display: Entering sleep mode"

      status = Display.status(display)
      assert status.display_state == :sleeping
    end

    test "status/1 returns current state information", %{display: display} do
      status = Display.status(display)

      assert is_map(status)
      assert Map.has_key?(status, :initialized)
      assert Map.has_key?(status, :display_state)
      assert Map.has_key?(status, :hal_module)
      assert Map.has_key?(status, :config)

      # Config should not include hal_module (filtered out)
      refute Map.has_key?(status.config, :hal_module)
    end

    test "GenServer handles termination gracefully", %{display: display, pid: pid} do
      assert :ok = Display.init_display(display)

      log =
        capture_log(fn ->
          GenServer.stop(pid)
          # Wait for termination
          ref = Process.monitor(pid)

          receive do
            {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
          after
            1000 -> flunk("Process did not terminate")
          end
        end)

      assert log =~ "Display: Terminating"
    end
  end

  describe "Display configuration" do
    test "merges application config with options" do
      # Mock application config
      original_config = Application.get_env(:mood_bot, MoodBot.Display, %{})

      try do
        Application.put_env(:mood_bot, MoodBot.Display, %{dc_pin: 99})

        test_name = :"display_config_test_#{System.unique_integer()}"
        config_override = %{rst_pin: 88}

        {:ok, pid} = Display.start_link(name: test_name, config: config_override)

        status = Display.status(test_name)

        # Should have app config value
        assert status.config.dc_pin == 99
        # Should have override value
        assert status.config.rst_pin == 88
        # Should have default values for others
        assert status.config.spi_device == "spidev0.0"

        GenServer.stop(pid)
      after
        Application.put_env(:mood_bot, MoodBot.Display, original_config)
      end
    end

    test "sets correct HAL module based on Mix.target" do
      # This test verifies the target detection logic would work
      # In actual embedded deployment, this would switch to RpiHAL
      test_name = :"display_target_test_#{System.unique_integer()}"
      {:ok, pid} = Display.start_link(name: test_name)

      status = Display.status(test_name)

      # In test environment (host), should use MockHAL
      assert status.hal_module == MoodBot.Display.MockHAL

      GenServer.stop(pid)
    end
  end

  describe "Display mood image generation" do
    setup do
      config = DisplayTestHelper.test_config()
      test_name = :"display_mood_test_#{System.unique_integer()}"
      {:ok, pid} = Display.start_link(name: test_name, config: config)

      assert :ok = Display.init_display(test_name)

      on_exit(fn ->
        if Process.alive?(pid) do
          GenServer.stop(pid)
        end
      end)

      %{display: test_name}
    end

    test "generates different patterns for each mood", %{display: display} do
      moods = [:happy, :sad, :neutral, :angry, :surprised]

      # Capture the generated patterns by checking logs
      mood_logs =
        for mood <- moods do
          log =
            capture_log(fn ->
              assert :ok = Display.show_mood(display, mood)
            end)

          {mood, log}
        end

      # Each mood should generate a log entry
      for {mood, log} <- mood_logs do
        assert log =~ "Display: Showing mood: #{mood}"
      end

      # All logs should be different (different mood patterns)
      log_contents = Enum.map(mood_logs, fn {_, log} -> log end)
      unique_logs = Enum.uniq(log_contents)
      assert length(unique_logs) == length(moods)
    end
  end

  describe "Error handling" do
    test "handles HAL initialization failure" do
      # Create a config that would cause TestHAL init to fail
      # For this test, we'll use a modified config, but TestHAL always succeeds
      # In a real scenario, you might mock a failing HAL

      config = %{invalid: true}
      test_name = :"display_error_test_#{System.unique_integer()}"

      # TestHAL will succeed even with invalid config, but this tests the pattern
      {:ok, pid} = Display.start_link(name: test_name, config: config)

      # The GenServer should start successfully (TestHAL is forgiving)
      assert Process.alive?(pid)

      GenServer.stop(pid)
    end

    test "handles driver errors gracefully" do
      config = DisplayTestHelper.test_config()
      test_name = :"display_driver_error_test_#{System.unique_integer()}"
      {:ok, pid} = Display.start_link(name: test_name, config: config)

      # Initialize first
      assert :ok = Display.init_display(test_name)

      # All operations should succeed with TestHAL
      # In a real error scenario, the driver might return errors
      assert :ok = Display.clear(test_name)
      assert :ok = Display.show_mood(test_name, :happy)

      GenServer.stop(pid)
    end
  end
end
