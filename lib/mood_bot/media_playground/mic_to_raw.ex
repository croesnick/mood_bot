defmodule MoodBot.MediaPlayground.MicToRaw do
  @moduledoc """
  A simple Membrane pipeline that captures audio from the microphone,
  resamples it using FFmpeg, and writes the raw audio data to a file.
  """

  use Membrane.Pipeline
  alias Membrane.{PortAudio, File}

  def handle_init(_ctx, location) do
    # %Source{} type: https://hexdocs.pm/membrane_portaudio_plugin/Membrane.PortAudio.Source.html#t:t/0
    # Whisper internally resample the input to 16kHz, mono, 16-bit PCM: https://github.com/openai/whisper/blob/main/whisper/audio.py#L45
    # So let's use this format directly to avoid unnecessary resampling.
    spec =
      child(%PortAudio.Source{sample_format: :s16le, channels: 1, sample_rate: 16_000})
      |> child(%File.Sink{location: location})

    {[spec: spec], %{}}
  end

  @doc """
  Prints names and ids of available audio devices to stdout.
  """
  def list_devices() do
    Membrane.PortAudio.print_devices()
  end
end
