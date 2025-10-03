defmodule MoodBot.STT2.StreamingPipeline do
  @moduledoc """
  Membrane pipeline for streaming audio transcription.

  ## Pipeline Flow
  ```
  PortAudio.Source (16kHz s16le mono)
    ↓
  AudioChunker (5-second chunks)
    ↓
  WhisperSink (progressive transcription)
    ↓
  Callback messages to Manager
  ```

  ## Progressive Transcription Strategy
  - **AudioChunker**: Emits 5s audio chunks (160KB for s16le @ 16kHz)
  - **WhisperSink**: Feeds chunks to Bumblebee serving
  - **Bumblebee**: Accumulates chunks into 30s windows with 5s overlap
  - **Result**: Progressive transcription without context loss

  ## Configuration
  - `whisper_serving` - Nx.Serving configured with streaming parameters
  - `callback_pid` - Process to receive `{:transcription_chunk, text, chunk_num}` messages

  ## Optional: Debug Recording
  To save raw audio for debugging, add a Tee branch:
  ```elixir
  child(:tee, Membrane.Tee.Parallel)
  child(:debug_file, %Membrane.File.Sink{location: "/tmp/debug_recording.raw"})
  get_child(:chunker) |> via_in(:input) |> to(:tee)
  get_child(:tee) |> via_out(:output) |> to(:whisper)
  get_child(:tee) |> via_out(:output) |> to(:debug_file)
  ```
  """
  use Membrane.Pipeline

  require Membrane.Logger

  @impl true
  def handle_init(_ctx, opts) do
    Membrane.Logger.info("StreamingPipeline starting with progressive transcription")

    spec = [
      child(:mic, %Membrane.PortAudio.Source{
        sample_format: :s16le,
        channels: 1,
        sample_rate: 16_000
      }),
      child(:chunker, %MoodBot.STT2.AudioChunker{
        chunk_duration: Membrane.Time.seconds(5)
      }),
      child(:whisper, %MoodBot.STT2.WhisperSink{
        serving: opts[:whisper_serving],
        callback_pid: opts[:callback_pid]
      }),
      get_child(:mic)
      |> child(:chunker)
      |> child(:whisper)
    ]

    {[spec: spec], %{}}
  end

  @impl true
  def handle_child_notification(notification, element, _ctx, state) do
    Membrane.Logger.debug("Child #{inspect(element)} notification: #{inspect(notification)}")
    {[], state}
  end
end
