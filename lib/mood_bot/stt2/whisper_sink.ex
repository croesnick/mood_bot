defmodule MoodBot.STT2.WhisperSink do
  @moduledoc """
  Custom Membrane sink that performs Whisper transcription on audio chunks.

  This element receives audio buffers (chunks from AudioChunker), converts them
  to tensors, runs Whisper transcription via Bumblebee serving, and sends results
  to a callback process.

  ## Progressive Transcription Flow
  1. Receive 5-second audio chunk from AudioChunker
  2. Convert s16le binary → f32 tensor
  3. Feed to Bumblebee serving (with streaming config)
  4. Bumblebee accumulates chunks into 30s windows with 5s overlap
  5. Send transcription text to callback_pid
  6. Repeat for next chunk

  ## Configuration
  - `serving` - Nx.Serving.t() configured for streaming transcription
  - `callback_pid` - Process to receive transcription results

  ## Messages Sent
  - `{:transcription_chunk, text}` - Progressive transcription result
  - `:transcription_complete` - All audio processed, stream ended
  """
  use Membrane.Sink

  require Membrane.Logger

  def_input_pad(:input,
    accepted_format: Membrane.RawAudio,
    flow_control: :auto
  )

  def_options(
    serving: [
      spec: Nx.Serving.t(),
      description: "Bumblebee Whisper serving for transcription"
    ],
    callback_pid: [
      spec: pid(),
      description: "Process to receive transcription results"
    ]
  )

  @impl true
  def handle_init(_ctx, opts) do
    {[],
     %{
       serving: opts.serving,
       callback_pid: opts.callback_pid,
       chunk_count: 0
     }}
  end

  @impl true
  def handle_stream_format(:input, _stream_format, _ctx, state) do
    {[], state}
  end

  @impl true
  def handle_buffer(:input, buffer, _ctx, state) do
    chunk_num = state.chunk_count + 1

    Membrane.Logger.debug(
      "WhisperSink processing chunk #{chunk_num}: #{byte_size(buffer.payload)} bytes"
    )

    # Convert s16le binary → f32 tensor
    samples =
      for <<s::signed-little-16 <- buffer.payload>> do
        s / 32_768.0
      end

    tensor = Nx.tensor(samples, type: :f32)

    # Run Whisper transcription (blocks until done)
    # With streaming config, Bumblebee accumulates chunks into 30s windows
    start_time = System.monotonic_time(:millisecond)
    output = Nx.Serving.run(state.serving, tensor)
    duration = System.monotonic_time(:millisecond) - start_time

    text =
      output.results
      |> List.first()
      |> case do
        nil -> ""
        result -> Map.get(result, :text, "")
      end

    Membrane.Logger.debug(
      "WhisperSink chunk #{chunk_num} transcribed in #{duration}ms: #{String.slice(text, 0, 50)}..."
    )

    # Send result to callback process
    send(state.callback_pid, {:transcription_chunk, text, chunk_num})

    {[], %{state | chunk_count: chunk_num}}
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    Membrane.Logger.info("WhisperSink completed: #{state.chunk_count} chunks processed")

    send(state.callback_pid, :transcription_complete)
    {[], state}
  end
end
