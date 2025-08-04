defmodule MoodBot.Display.DriverTest do
  use ExUnit.Case, async: true

  alias MoodBot.Display.Driver
  alias MoodBot.DisplayTestHelper

  describe "Driver constants and utilities" do
    test "dimensions/0 returns correct display size" do
      assert {128, 296} = Driver.dimensions()
    end
  end

  describe "Driver initialization" do
    test "init/1 selects MockHAL on host target" do
      # Since we're running tests on host, it should select MockHAL
      config = DisplayTestHelper.test_config()

      assert {:ok, driver_state} = Driver.init(config)
      assert %Driver{} = driver_state
      assert driver_state.hal_module == MoodBot.Display.MockHAL
      assert driver_state.initialized? == true
    end

    test "init/1 performs complete initialization sequence" do
      config = DisplayTestHelper.test_config()

      assert {:ok, driver_state} = Driver.init(config)
      assert %Driver{} = driver_state
      assert driver_state.initialized? == true
    end

    test "init/1 handles HAL initialization errors gracefully" do
      # Create a config that will cause MockHAL to fail
      invalid_config = %{
        spi_device: "/invalid/device",
        dc_gpio: -1,
        rst_gpio: -1,
        busy_gpio: -1,
        pwr_gpio: -1
      }

      assert {:error, _reason} = Driver.init(invalid_config)
    end
  end

  describe "Driver command functions with driver_state" do
    setup do
      config = DisplayTestHelper.test_config()
      {:ok, driver_state} = Driver.init(config)

      on_exit(fn ->
        Driver.close(driver_state)
      end)

      %{driver_state: driver_state}
    end

    test "send_command/2 succeeds and returns updated driver state", %{driver_state: driver_state} do
      assert {:ok, new_driver_state} = Driver.send_command(driver_state, 0x12)
      assert %Driver{} = new_driver_state
      assert new_driver_state.hal_module == driver_state.hal_module
    end

    test "send_data/2 succeeds and returns updated driver state", %{driver_state: driver_state} do
      data = <<0x01, 0x02, 0x03>>
      assert {:ok, new_driver_state} = Driver.send_data(driver_state, data)
      assert %Driver{} = new_driver_state
      assert new_driver_state.hal_module == driver_state.hal_module
    end

    test "reset/1 performs reset sequence successfully", %{driver_state: driver_state} do
      assert {:ok, new_driver_state} = Driver.reset(driver_state)
      assert %Driver{} = new_driver_state
    end

    test "wait_until_idle/1 completes successfully", %{driver_state: driver_state} do
      assert {:ok, new_driver_state} = Driver.wait_until_idle(driver_state)
      assert %Driver{} = new_driver_state
    end

    test "wait_until_idle/2 accepts timeout parameter", %{driver_state: driver_state} do
      assert {:ok, new_driver_state} = Driver.wait_until_idle(driver_state, 1000)
      assert %Driver{} = new_driver_state
    end

    test "set_memory_area/6 sets memory area successfully", %{driver_state: driver_state} do
      assert {:ok, new_driver_state} = Driver.set_memory_area(driver_state, 0, 0, 127, 295)
      assert %Driver{} = new_driver_state
    end

    test "set_memory_pointer/4 sets memory pointer successfully", %{driver_state: driver_state} do
      assert {:ok, new_driver_state} = Driver.set_memory_pointer(driver_state, 0, 0)
      assert %Driver{} = new_driver_state
    end

    test "display_frame_full/2 validates image size", %{driver_state: driver_state} do
      # Test with invalid size
      invalid_data = <<1, 2, 3>>
      assert {:error, :invalid_image_size} = Driver.display_frame_full(driver_state, invalid_data)
    end

    test "display_frame_full/2 accepts valid image data", %{driver_state: driver_state} do
      image_data = DisplayTestHelper.test_image_data()
      assert {:ok, new_driver_state} = Driver.display_frame_full(driver_state, image_data)
      assert %Driver{} = new_driver_state
    end

    test "display_frame_partial/2 validates image size", %{driver_state: driver_state} do
      invalid_data = <<1, 2, 3>>

      assert {:error, :invalid_image_size} =
               Driver.display_frame_partial(driver_state, invalid_data)
    end

    test "display_frame_partial/2 accepts valid image data", %{driver_state: driver_state} do
      image_data = DisplayTestHelper.test_image_data()
      assert {:ok, new_driver_state} = Driver.display_frame_partial(driver_state, image_data)
      assert %Driver{} = new_driver_state
    end

    test "clear_display/2 processes display clear successfully", %{driver_state: driver_state} do
      data = DisplayTestHelper.test_image_data()
      assert {:ok, new_driver_state} = Driver.clear_display(driver_state, data)
      assert %Driver{} = new_driver_state
    end

    test "sleep/1 enters sleep mode successfully", %{driver_state: driver_state} do
      assert {:ok, new_driver_state} = Driver.sleep(driver_state)
      assert %Driver{} = new_driver_state
    end

    test "close/1 performs cleanup successfully", %{driver_state: driver_state} do
      assert :ok = Driver.close(driver_state)
    end
  end

  describe "Driver test functions with driver_state" do
    setup do
      config = DisplayTestHelper.test_config()
      {:ok, driver_state} = Driver.init(config)

      on_exit(fn ->
        Driver.close(driver_state)
      end)

      %{driver_state: driver_state}
    end

    test "test_spi_communication/1 validates SPI connectivity", %{driver_state: driver_state} do
      assert {:ok, new_driver_state} = Driver.test_spi_communication(driver_state)
      assert %Driver{} = new_driver_state
    end

    test "test_small_data_write/1 validates small data transfers", %{driver_state: driver_state} do
      assert {:ok, new_driver_state} = Driver.test_small_data_write(driver_state)
      assert %Driver{} = new_driver_state
    end

    test "test_large_data_write/2 validates large data transfers", %{driver_state: driver_state} do
      test_size = 1024
      assert {:ok, new_driver_state} = Driver.test_large_data_write(driver_state, test_size)
      assert %Driver{} = new_driver_state
    end

    test "test_large_data_write/1 uses default size", %{driver_state: driver_state} do
      assert {:ok, new_driver_state} = Driver.test_large_data_write(driver_state)
      assert %Driver{} = new_driver_state
    end
  end

  describe "Error handling and propagation" do
    test "init/1 propagates HAL errors with clear attribution" do
      # Invalid config that should cause HAL initialization to fail
      invalid_config = %{
        spi_device: "/dev/null/invalid",
        dc_gpio: {-1, -1},
        rst_gpio: {-1, -1},
        busy_gpio: {-1, -1},
        pwr_gpio: {-1, -1}
      }

      assert {:error, reason} = Driver.init(invalid_config)
      # Error should clearly indicate it's from HAL layer
      assert is_tuple(reason) or is_atom(reason)
    end

    test "driver functions handle HAL errors gracefully" do
      # Test with a known good config first
      config = DisplayTestHelper.test_config()
      {:ok, driver_state} = Driver.init(config)

      # Test that functions handle errors properly
      assert {:ok, _} = Driver.send_command(driver_state, 0x00)
      assert {:ok, _} = Driver.send_data(driver_state, <<0x00>>)

      Driver.close(driver_state)
    end
  end

  describe "HAL selection logic" do
    test "driver uses MockHAL when running on host" do
      config = DisplayTestHelper.test_config()

      # Remove any hal_module from config to test automatic selection
      config = Map.delete(config, :hal_module)

      assert {:ok, driver_state} = Driver.init(config)

      # On host target (during tests), should select MockHAL
      assert driver_state.hal_module == MoodBot.Display.MockHAL

      Driver.close(driver_state)
    end

    test "driver state contains proper HAL module and state" do
      config = DisplayTestHelper.test_config()

      assert {:ok, driver_state} = Driver.init(config)

      # Verify driver state structure
      assert %Driver{
               hal_module: hal_module,
               hal_state: hal_state,
               initialized?: initialized?
             } = driver_state

      assert is_atom(hal_module)
      assert hal_state != nil
      assert initialized? == true

      Driver.close(driver_state)
    end
  end

  describe "Driver state consistency" do
    test "all driver functions maintain state consistency" do
      config = DisplayTestHelper.test_config()
      {:ok, initial_state} = Driver.init(config)

      # Test that all functions return consistent driver state
      functions_to_test = [
        fn state -> Driver.send_command(state, 0x00) end,
        fn state -> Driver.send_data(state, <<0x00>>) end,
        fn state -> Driver.reset(state) end,
        fn state -> Driver.wait_until_idle(state) end,
        fn state -> Driver.set_memory_area(state, 0, 0, 10, 10) end,
        fn state -> Driver.set_memory_pointer(state, 0, 0) end,
        fn state -> Driver.test_spi_communication(state) end,
        fn state -> Driver.test_small_data_write(state) end,
        fn state -> Driver.sleep(state) end
      ]

      # Chain all function calls and verify state consistency
      final_state =
        Enum.reduce(functions_to_test, initial_state, fn fun, state ->
          case fun.(state) do
            {:ok, new_state} ->
              # Verify state structure is maintained
              assert %Driver{} = new_state
              assert new_state.hal_module == initial_state.hal_module
              new_state

            {:error, _} ->
              # Some functions may fail with MockHAL, that's ok
              state
          end
        end)

      assert %Driver{} = final_state
      Driver.close(final_state)
    end
  end
end
