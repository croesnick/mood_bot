defmodule MoodBot.STT2.AudioChunker do
  @moduledoc """
  Custom Membrane filter that buffers audio into fixed-duration chunks.

  This element accumulates incoming audio buffers and emits complete chunks
  when the specified duration threshold is reached. Partial data is retained
  for the next chunk.

  ## Purpose
  Controls the rate at which audio data flows to downstream elements (WhisperSink),
  creating predictable chunk sizes for progressive transcription.

  ## Configuration
  - `chunk_duration` - Target duration for each chunk (e.g., `Membrane.Time.seconds(5)`)

  ## Audio Format
  Expects s16le (signed 16-bit little-endian) mono audio at 16kHz sample rate.
  - 1 sample = 2 bytes
  - 16kHz = 16,000 samples/second = 32,000 bytes/second
  - 5 second chunk = 160,000 bytes
  """
  use Membrane.Filter

  require Membrane.Logger

  def_input_pad(:input,
    accepted_format: Membrane.RawAudio,
    flow_control: :auto
  )

  def_output_pad(:output,
    accepted_format: Membrane.RawAudio,
    flow_control: :auto
  )

  def_options(
    chunk_duration: [
      spec: Membrane.Time.t(),
      description: "Duration of each audio chunk to emit"
    ]
  )

  @impl true
  def handle_init(_ctx, opts) do
    {[], %{chunk_duration: opts.chunk_duration, buffer: <<>>, bytes_per_chunk: nil}}
  end

  @impl true
  def handle_stream_format(:input, stream_format, _ctx, state) do
    # Calculate bytes per chunk based on audio format
    # s16le = 2 bytes per sample, mono = 1 channel
    sample_rate = stream_format.sample_rate
    bytes_per_sample = 2
    bytes_per_second = sample_rate * bytes_per_sample

    bytes_per_chunk =
      trunc(Membrane.Time.as_seconds(state.chunk_duration, :round) * bytes_per_second)

    Membrane.Logger.debug(
      "AudioChunker initialized: #{bytes_per_chunk} bytes per chunk (#{sample_rate}Hz, #{Membrane.Time.as_seconds(state.chunk_duration, :round)}s)"
    )

    state = %{state | bytes_per_chunk: bytes_per_chunk}
    {[forward: stream_format], state}
  end

  @impl true
  def handle_buffer(:input, buffer, _ctx, state) do
    # Accumulate incoming data
    accumulated = state.buffer <> buffer.payload

    # Emit complete chunks
    {chunks, remainder} = split_into_chunks(accumulated, state.bytes_per_chunk, [])

    # Create output buffers for each complete chunk
    output_buffers =
      Enum.map(chunks, fn chunk_data ->
        %Membrane.Buffer{payload: chunk_data}
      end)

    actions = Enum.map(output_buffers, fn buf -> {:buffer, {:output, buf}} end)

    {actions, %{state | buffer: remainder}}
  end

  @impl true
  def handle_end_of_stream(:input, _ctx, state) do
    # Flush any remaining data as final chunk
    actions =
      if byte_size(state.buffer) > 0 do
        Membrane.Logger.debug("Flushing final chunk: #{byte_size(state.buffer)} bytes (partial)")

        [buffer: {:output, %Membrane.Buffer{payload: state.buffer}}]
      else
        []
      end

    {actions ++ [end_of_stream: :output], %{state | buffer: <<>>}}
  end

  # Private helpers

  defp split_into_chunks(data, bytes_per_chunk, acc) when byte_size(data) >= bytes_per_chunk do
    <<chunk::binary-size(bytes_per_chunk), rest::binary>> = data
    split_into_chunks(rest, bytes_per_chunk, [chunk | acc])
  end

  defp split_into_chunks(remainder, _bytes_per_chunk, acc) do
    {Enum.reverse(acc), remainder}
  end
end
