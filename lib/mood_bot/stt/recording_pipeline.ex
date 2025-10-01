defmodule MoodBot.STT.RecordingPipeline do
  @moduledoc """
  Membrane pipeline for recording audio from PortAudio to file.
  Records raw PCM audio (s16le, 16kHz, mono) suitable for Whisper.
  """

  use Membrane.Pipeline

  require Logger

  @impl true
  def handle_init(_ctx, output_file) do
    spec = [
      child(:source, %Membrane.PortAudio.Source{
        sample_format: :s16le,
        sample_rate: 16_000,
        channels: 1
      })
      |> child(:sink, %Membrane.File.Sink{
        location: output_file
      })
    ]

    {[spec: spec], %{output_file: output_file}}
  end

  @impl true
  def handle_child_notification(:end_of_stream, :sink, _ctx, state) do
    Logger.info("Recording complete: #{state.output_file}")
    {[], state}
  end

  @impl true
  def handle_child_notification(_notification, _child, _ctx, state) do
    {[], state}
  end
end
