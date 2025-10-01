# Whisper STT - Phase 2 (Streaming Transcription)

**Goal:** Add progressive transcription feedback during recording

**When to implement:** Post-conference, when users want real-time feedback

**Reference:** Full research and details in [whisper.md](./whisper.md)

## Changes from Phase 1

### Architecture

```
Phase 1:  PortAudio → File.Sink → [stop] → transcribe_file()
Phase 2:  PortAudio → AudioChunker → WhisperSink → [progressive output]
```

### Additional Components

#### 1. AudioChunker (Custom Membrane Filter)

- **Purpose:** Buffer audio into 5s chunks for progressive processing
- **Why needed:** No built-in Membrane element for time-based chunking
- **Implementation:** ~80 lines (see whisper.md lines 44-114 for code skeleton)

#### 2. WhisperSink (Custom Membrane Sink)

- **Purpose:** Interface between Membrane and Bumblebee
- **Responsibilities:**
  - Convert s16le binary → f32 tensor
  - Feed to Bumblebee serving (with `chunk_num_seconds: 30, stream: true`)
  - Send transcription chunks to callback PID
  - Handle end of stream

#### 3. StreamingPipeline (Replaces RecordingPipeline)

- **Flow:** PortAudio → AudioChunker → WhisperSink
- **Optional:** Add Tee branch to File.Sink for debugging

## Key Concepts

### Two-Level Chunking

**Layer 1: AudioChunker (Feed Rate)**

- Chunks: 5 seconds (80KB for s16le @ 16kHz)
- Purpose: Control how fast data flows to Bumblebee

**Layer 2: Bumblebee Processing (Transcription Window)**

- Chunks: 30 seconds with 5s overlap
- Purpose: Actual Whisper processing window
- **Key insight:** Bumblebee accumulates 5s chunks into 30s windows with overlap
- **Result:** No context loss, good sentence boundaries

```
AudioChunker feeds:    [5s][5s][5s][5s][5s][5s]...
Bumblebee processes:   [--------30s--------]
                            [--------30s--------]
                                 [--------30s--------]
                         (5s overlap)  (5s overlap)
```

## Implementation Outline

### WhisperSink (Condensed)

```elixir
defmodule MoodBot.STT.WhisperSink do
  use Membrane.Sink

  def_input_pad :input, accepted_format: Membrane.RawAudio, flow_control: :auto
  def_options serving: [spec: Nx.Serving.t()], callback_pid: [spec: pid()]

  def handle_init(_ctx, opts) do
    {[], %{serving: opts.serving, callback_pid: opts.callback_pid}}
  end

  def handle_buffer(:input, buffer, _ctx, state) do
    # Convert s16le → f32 tensor
    samples = for <<s::signed-little-16 <- buffer.payload>>, do: s / 32768.0
    tensor = Nx.tensor(samples, type: :f32)

    # Run Whisper (blocks until done)
    output = Nx.Serving.run(state.serving, tensor)
    text = output.results |> List.first() |> Map.get(:text, "")

    # Send to manager
    send(state.callback_pid, {:transcription_chunk, text})

    {[], state}
  end

  def handle_end_of_stream(:input, _ctx, state) do
    send(state.callback_pid, :transcription_complete)
    {[], state}
  end
end
```

### StreamingPipeline (Condensed)

```elixir
defmodule MoodBot.STT.StreamingPipeline do
  use Membrane.Pipeline

  def handle_init(_ctx, opts) do
    spec = [
      child(:mic, %Membrane.PortAudio.Source{sample_format: :s16le, channels: 1, sample_rate: 16_000}),
      child(:chunker, %MoodBot.STT.AudioChunker{chunk_duration: Membrane.Time.seconds(5)}),
      child(:whisper, %MoodBot.STT.WhisperSink{
        serving: opts[:whisper_serving],
        callback_pid: opts[:callback_pid]
      }),
      get_child(:mic) |> to(:chunker) |> to(:whisper)
    ]
    {[spec: spec], %{}}
  end
end
```

### STT.Manager Changes

```elixir
# In handle_call(:start_recording, ...)
{:ok, _sup, pipeline_pid} = StreamingPipeline.start_link(
  whisper_serving: state.whisper_serving,
  callback_pid: self()
)

# Add new callback
def handle_info({:transcription_chunk, text}, state) do
  IO.puts("Partial: #{text}")
  # Or: send to display, accumulate, etc.
  {:noreply, state}
end

def handle_info(:transcription_complete, state) do
  IO.puts("Transcription finished")
  {:noreply, state}
end
```

## AudioChunker Implementation

**Full code skeleton:** See [whisper.md](./whisper.md) lines 44-114

**Key logic:**

1. Calculate `bytes_per_chunk` based on sample rate and desired duration
2. Accumulate incoming buffers until threshold reached
3. Emit complete chunks, keep remainder for next iteration

## Configuration

### Bumblebee Serving Setup

```elixir
Bumblebee.Audio.speech_to_text_whisper(
  whisper, featurizer, tokenizer, generation_config,
  chunk_num_seconds: 30,      # Internal processing window
  context_num_seconds: 5,     # Overlap for context
  stream: true,               # Progressive output
  defn_options: [compiler: EXLA]
)
```

## Benefits vs Phase 1

✅ **Progressive feedback:** See transcription appear while recording
✅ **Better UX:** User knows system is "listening"
✅ **Long recordings:** Better for >60s recordings
✅ **Context preserved:** Overlapping windows prevent word splitting

## Costs vs Phase 1

⚠️ **Complexity:** +150 lines (AudioChunker + WhisperSink)
⚠️ **Latency:** Each 30s chunk takes ~2-5s to process on RPi4
⚠️ **Memory:** Slightly higher (buffering multiple chunks)

## Migration Path

1. Implement AudioChunker (use skeleton from whisper.md)
2. Implement WhisperSink (see condensed version above)
3. Create StreamingPipeline
4. Update STT.Manager to use StreamingPipeline
5. Add UI for displaying partial transcriptions
6. Test with >60s recordings

## Testing Approach

**File-based testing:**

```elixir
# Replace PortAudio.Source with File.Source
child(:source, %Membrane.File.Source{location: "test/fixtures/long_recording.raw"})
```

**Verify:**

- Chunks arrive progressively
- Overlapping transcriptions merge correctly
- No word splitting at boundaries
- Memory usage acceptable

## When NOT to Use Phase 2

Stick with Phase 1 (file-based) if:

- Recordings are consistently <30s
- Users don't need real-time feedback
- Simplicity is more important than UX polish
- Conference deadline approaching

## Full Documentation

For complete details:

- **AudioChunker code skeleton:** [whisper.md](./whisper.md) lines 44-114
- **Two-level chunking explanation:** [whisper.md](./whisper.md) lines 157-226
- **Context preservation details:** [whisper.md](./whisper.md) lines 205-224
- **Pipeline lifecycle control:** [whisper.md](./whisper.md) lines 266-430
- **All research and references:** [whisper.md](./whisper.md) lines 547-591
