defmodule Mix.Tasks.TestStt do
  @moduledoc """
  Test the STT recording pipeline by recording audio and transcribing it.

  Usage:
    mix test_stt [duration_in_seconds]

  Examples:
    mix test_stt       # Record for 5 seconds
    mix test_stt 10    # Record for 10 seconds
  """

  use Mix.Task

  @shortdoc "Test STT recording and transcription"
  @default_duration 5

  @impl Mix.Task
  def run(args) do
    duration = parse_duration(args)

    # Start application and dependencies
    Mix.Task.run("app.start")

    # Interactive device selection
    case select_device() do
      {:error, _} ->
        :ok

      device_id ->
        test_recording(duration, device_id)
    end
  end

  defp parse_duration([seconds_str]) do
    case Integer.parse(seconds_str) do
      {seconds, ""} when seconds > 0 ->
        seconds

      _ ->
        Mix.shell().error("Invalid duration. Using default: #{@default_duration}s")
        @default_duration
    end
  end

  defp parse_duration(_), do: @default_duration

  defp select_device do
    devices = Membrane.PortAudio.list_devices()

    # Filter input devices only
    input_devices =
      devices
      |> Enum.filter(fn d -> d.max_input_channels > 0 end)
      |> Enum.sort_by(fn d ->
        # 16kHz first (0), then others (1)
        if d.default_sample_rate == 16_000.0, do: 0, else: 1
      end)

    if Enum.empty?(input_devices) do
      Mix.shell().error("No input devices found!")
      {:error, :no_devices}
    else
      display_devices(input_devices)
      prompt_for_device(input_devices)
    end
  end

  defp display_devices(devices) do
    Mix.shell().info("\nAvailable input devices:")

    devices
    |> Enum.with_index(1)
    |> Enum.each(fn {device, idx} ->
      default_marker = if device.default_device == :input, do: " (default)", else: ""
      sample_rate_marker = if device.default_sample_rate == 16_000.0, do: " ✓", else: ""

      Mix.shell().info(
        "  #{idx}. #{device.name}#{default_marker} - #{trunc(device.default_sample_rate)}Hz#{sample_rate_marker}"
      )
    end)

    Mix.shell().info("\n✓ = Native 16kHz (optimal)")
  end

  defp prompt_for_device(devices) do
    prompt = "\nSelect device (1-#{length(devices)}, or Enter for default): "

    case Mix.shell().prompt(prompt) |> String.trim() do
      "" ->
        # Use default device
        :default

      input ->
        case Integer.parse(input) do
          {num, ""} when num >= 1 and num <= length(devices) ->
            device = Enum.at(devices, num - 1)
            device.id

          _ ->
            Mix.shell().error("Invalid selection. Using default device.")
            :default
        end
    end
  end

  defp test_recording(duration, device_id) do
    device_name = if device_id == :default, do: "default", else: "##{device_id}"

    Mix.shell().info("\nUsing device: #{device_name}")
    Mix.shell().info("Recording for #{duration} seconds...")
    Mix.shell().info(">>>  Speak into your microphone now!  <<<\n")

    case MoodBot.STT.Manager.start_recording(device_id) do
      :ok ->
        Process.sleep(duration * 1000)

        Mix.shell().info("Stopping recording and transcribing...")

        case MoodBot.STT.Manager.stop_recording_and_keep_file() do
          {:ok, text, file_path} ->
            Mix.shell().info("\nTranscription result:")
            Mix.shell().info(">>> #{text}")

            handle_file_actions(file_path)

          {:error, reason} ->
            Mix.shell().error("Transcription failed: #{inspect(reason)}")
        end

      {:error, :already_recording} ->
        Mix.shell().error("Recording already in progress")

      {:error, reason} ->
        Mix.shell().error("Failed to start recording: #{inspect(reason)}")
    end
  end

  defp handle_file_actions(file_path) do
    Mix.shell().info("\nOptions:")
    Mix.shell().info("  p - Play back the recording")
    Mix.shell().info("  i - show file path")
    Mix.shell().info("  d - Delete the file (default)")

    case Mix.shell().prompt("\nChoose (p/i/d/Enter): ") |> String.trim() |> String.downcase() do
      "p" ->
        play_audio(file_path)
        handle_file_actions(file_path)

      "i" ->
        Mix.shell().info("File kept at: #{file_path}")

      _ ->
        File.rm(file_path)
        Mix.shell().info("File deleted")
    end
  end

  defp play_audio(file_path) do
    Mix.shell().info("\nPlaying audio...")

    if System.find_executable("ffplay") do
      # Convert to WAV first for better compatibility
      wav_path = String.replace(file_path, ".raw", ".wav")

      case System.cmd("ffmpeg", [
             "-f",
             "s16le",
             "-ar",
             "16000",
             "-ac",
             "1",
             "-i",
             file_path,
             "-y",
             wav_path
           ]) do
        {_, 0} ->
          System.cmd("ffplay", ["-nodisp", "-autoexit", wav_path])
          File.rm(wav_path)

        _ ->
          Mix.shell().error("Failed to convert audio file")
      end
    else
      Mix.shell().error("ffplay not found. Install ffmpeg to play audio.")
    end
  end
end
