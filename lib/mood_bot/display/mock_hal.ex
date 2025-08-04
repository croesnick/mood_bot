defmodule MoodBot.Display.MockHAL do
  @moduledoc """
  Mock Hardware Abstraction Layer for development and testing.

  Implements the HAL behavior with simulated responses and logging
  for development when running on host without actual hardware.
  """

  use TypedStruct

  @behaviour MoodBot.Display.HAL

  require Logger

  @type config :: %{
          spi_device: String.t(),
          pwr_gpio: Circuits.GPIO.gpio_spec(),
          dc_gpio: Circuits.GPIO.gpio_spec(),
          rst_gpio: Circuits.GPIO.gpio_spec(),
          busy_gpio: Circuits.GPIO.gpio_spec()
        }

  typedstruct do
    field(:config, config())
    field(:session_id, String.t())
    field(:dc_state, 0 | 1, default: 0)
    field(:rst_state, 0 | 1, default: 1)
    field(:busy_state, 0 | 1, default: 0)
    field(:frame_counter, non_neg_integer(), default: 0)
    field(:save_bitmaps, boolean(), default: false)
  end

  @impl true
  @spec init(config()) :: {:ok, t()} | {:error, atom()}
  def init(config) do
    Logger.debug("Initializing MockHAL with config: #{inspect(config)}")

    # Validate configuration format for development consistency
    case validate_mock_config(config) do
      :ok ->
        session_id = :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
        save_bitmaps = Map.get(config, :save_bitmaps, true)

        state = %__MODULE__{
          config: config,
          session_id: session_id,
          dc_state: 0,
          rst_state: 1,
          busy_state: 0,
          frame_counter: 0,
          save_bitmaps: save_bitmaps
        }

        if save_bitmaps do
          Logger.info(
            "MockHAL initialized for development mode with bitmap saving enabled (session: #{session_id})"
          )
        else
          Logger.info("MockHAL initialized for development mode")
        end

        {:ok, state}

      {:error, reason} ->
        Logger.error("MockHAL configuration validation failed", error: reason, config: config)
        {:error, reason}
    end
  end

  # Expected size for full image data (128 * 296 / 8 = 4736 bytes)
  @image_data_size 4736

  @impl true
  def spi_write(state, data) when is_binary(data) do
    data_size = byte_size(data)

    Logger.debug(
      "MockHAL: SPI write #{data_size} bytes: #{inspect(binary_part(data, 0, min(8, data_size)))}..."
    )

    new_state = maybe_save_bitmap(state, data)

    {:ok, new_state}
  end

  # Private helper to detect and save bitmap data
  defp maybe_save_bitmap(%{save_bitmaps: false} = state, _data), do: state

  defp maybe_save_bitmap(%{save_bitmaps: true} = state, data) do
    data_size = byte_size(data)

    if data_size == @image_data_size and state.dc_state == 1 do
      # This looks like image data (correct size and DC pin is in data mode)
      case save_frame_bitmap(state, data) do
        :ok ->
          Logger.info(
            "MockHAL: Saved bitmap frame #{state.frame_counter} (session: #{state.session_id})"
          )

          %{state | frame_counter: state.frame_counter + 1}

        {:error, reason} ->
          Logger.error("MockHAL: Failed to save bitmap: #{reason}")
          state
      end
    else
      # Not image data (wrong size or in command mode)
      state
    end
  end

  defp save_frame_bitmap(state, data) do
    alias MoodBot.Display.Bitmap

    filename = Bitmap.generate_filename(state.session_id, state.frame_counter)
    Bitmap.save_pbm(data, filename)
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

  # Configuration validation functions

  defp validate_mock_config(config) do
    required_fields = [:spi_device, :pwr_gpio, :dc_gpio, :rst_gpio, :busy_gpio]

    case validate_required_fields(config, required_fields) do
      :ok ->
        validate_mock_field_types(config)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp validate_required_fields(config, required_fields) do
    missing_fields = required_fields -- Map.keys(config)

    if Enum.empty?(missing_fields) do
      :ok
    else
      Logger.error("MockHAL configuration validation failed: missing required fields",
        missing_fields: missing_fields,
        required_fields: required_fields
      )

      {:error, {:missing_config_fields, missing_fields}}
    end
  end

  defp validate_mock_field_types(config) do
    validations = [
      {:spi_device, config.spi_device, &is_binary/1, "string"},
      {:pwr_gpio, config.pwr_gpio, &valid_gpio_spec?/1, "valid GPIO specification"},
      {:dc_gpio, config.dc_gpio, &valid_gpio_spec?/1, "valid GPIO specification"},
      {:rst_gpio, config.rst_gpio, &valid_gpio_spec?/1, "valid GPIO specification"},
      {:busy_gpio, config.busy_gpio, &valid_gpio_spec?/1, "valid GPIO specification"}
    ]

    Enum.reduce_while(validations, :ok, fn {field_name, value, validator, type_name}, _acc ->
      if validator.(value) do
        {:cont, :ok}
      else
        Logger.error("MockHAL configuration validation failed: invalid field type",
          field: field_name,
          value: value,
          expected_type: type_name
        )

        {:halt, {:error, {:invalid_config_field_type, field_name, type_name}}}
      end
    end)
  end

  defp valid_gpio_spec?(value) do
    case value do
      {controller, offset} when is_binary(controller) and is_integer(offset) and offset >= 0 ->
        true

      pin_number when is_integer(pin_number) and pin_number >= 0 ->
        true

      _ ->
        false
    end
  end
end
