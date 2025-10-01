# Whisper - speech-to-text

**Goal:** Voice interaction - record speech, transcribe to text, generate LLM response, speak via TTS.

**Phase 1 (MVP - Conference Demo):** File-based recording → complete transcription → LLM → TTS
**Phase 2 (Extended - Post-Conference):** Add streaming transcription for progressive user feedback

This document covers both phases, with Phase 1 being the immediate implementation target.

## Feasibility Analysis - ✅ CONFIRMED FEASIBLE

Comprehensive research confirms both approaches are achievable:

1. **File-based recording (Phase 1):** ✅ Simple, proven
   - PortAudio → File.Sink → Whisper.transcribe_file()
   - Uses built-in Membrane elements only
   - Perfect for <60s recordings

2. **Streaming transcription (Phase 2):** ✅ Confirmed working
   - Membrane → Bumblebee integration possible
   - Custom filters/sinks needed (AudioChunker + WhisperSink)
   - Real-world examples exist (Membrane demos, Underjord VAD)

3. **Audio format:** ✅ Already optimal
   - PortAudio config (16kHz, mono, s16le) matches Whisper expectations
   - No resampling needed

## Implementation Plan

### Required Components

#### 1. AudioChunker (Custom Membrane Filter)

- **Purpose:** Buffer continuous audio stream into fixed-size chunks for Whisper
- **Type:** `Membrane.Filter`
- **Why custom?** No built-in Membrane element exists for time-based or size-based audio chunking. Connection-level buffers (`:buffer` option in `via_in/via_out`) are for flow control, not accumulation.
- **Logic:**
  - Accumulate audio bytes until chunk duration reached (5-10 seconds)
  - Emit complete chunks as buffers
  - Handle remainder bytes between chunks
- **Config:** Chunk duration in seconds (configurable)
- **Complexity:** ~50-80 lines of code (simple, well-established pattern)

**Example skeleton:**

```elixir
defmodule MoodBot.STT.AudioChunker do
  use Membrane.Filter

  def_input_pad :input,
    accepted_format: Membrane.RawAudio,
    flow_control: :auto

  def_output_pad :output,
    accepted_format: Membrane.RawAudio,
    flow_control: :auto

  def_options chunk_duration: [
    spec: Membrane.Time.t(),
    default: Membrane.Time.seconds(5),
    description: "Duration of each audio chunk"
  ]

  @impl true
  def handle_init(_ctx, opts) do
    state = %{
      chunk_duration: opts.chunk_duration,
      buffer: <<>>,
      sample_rate: nil,
      bytes_per_chunk: nil
    }
    {[], state}
  end

  @impl true
  def handle_stream_format(:input, stream_format, _ctx, state) do
    # Calculate bytes needed for desired chunk duration
    # For s16le: 2 bytes per sample
    bytes_per_second = stream_format.sample_rate * stream_format.channels * 2
    bytes_per_chunk = div(bytes_per_second * state.chunk_duration, Membrane.Time.second())

    state = %{state |
      sample_rate: stream_format.sample_rate,
      bytes_per_chunk: bytes_per_chunk
    }

    {[stream_format: {:output, stream_format}], state}
  end

  @impl true
  def handle_buffer(:input, buffer, _ctx, state) do
    # Accumulate incoming audio
    accumulated = state.buffer <> buffer.payload

    # Split into complete chunks
    {chunks, remainder} = split_into_chunks(accumulated, state.bytes_per_chunk)

    # Emit each complete chunk
    output_buffers = Enum.map(chunks, &%Membrane.Buffer{payload: &1})
    actions = Enum.map(output_buffers, &{:buffer, {:output, &1}})

    {actions, %{state | buffer: remainder}}
  end

  defp split_into_chunks(data, chunk_size) do
    if byte_size(data) >= chunk_size do
      <<chunk::binary-size(chunk_size), rest::binary>> = data
      {chunks, remainder} = split_into_chunks(rest, chunk_size)
      {[chunk | chunks], remainder}
    else
      {[], data}
    end
  end
end
```

#### 2. WhisperSink (Custom Membrane Sink)

- **Purpose:** Interface between Membrane pipeline and Bumblebee Whisper
- **Type:** `Membrane.Sink`
- **Responsibilities:**
  - Convert s16le binary audio → normalized f32 Nx tensor
  - Feed tensors to Bumblebee serving
  - Handle transcription results via callback function
  - Manage Bumblebee serving lifecycle

#### 3. StreamingSTTPipeline (Main Pipeline)

- **Purpose:** Orchestrate complete audio-to-text flow
- **Type:** `Membrane.Pipeline`
- **Flow:** `PortAudio.Source → AudioChunker → WhisperSink`

#### 4. STTController (GenServer)

- **Purpose:** Manage pipeline lifecycle and user interactions
- **Type:** `GenServer`
- **State:** Pipeline PID, Bumblebee serving, recording status
- **API:** `start_recording/0`, `stop_recording/0`, `status/0`

### Architecture Diagram

```
Button Press → STTController.start_recording()
     ↓
PortAudio.Source (PCM s16le, 16kHz, mono)
     ↓
AudioChunker (feed 5s chunks) → 80KB chunks every 5 seconds
     ↓
WhisperSink (s16le → f32 tensor)
     ↓
Bumblebee (accumulates to 30s windows with 5s overlap)
     ↓
Whisper Model (EXLA inference on 30s segments)
     ↓
Console Output (merged transcription)
```

### Understanding Two-Level Chunking

The architecture uses **two distinct chunking layers** that serve different purposes:

#### Layer 1: AudioChunker (Membrane Filter)

- **Purpose:** Control feed rate and latency
- **Chunk size:** 5 seconds (80KB for s16le @ 16kHz mono)
- **Function:** Progressive feeding to Bumblebee, not processing window
- **Does NOT lose context** - just controls when data is sent downstream

#### Layer 2: Bumblebee Internal Processing

- **Purpose:** Whisper's actual transcription window
- **Chunk size:** 30 seconds (configurable via `chunk_num_seconds`)
- **Overlap:** 5 seconds (configurable via `context_num_seconds`)
- **Function:** Accumulates audio, processes in overlapping windows, merges results

**Visual representation:**

```
AudioChunker feeds:    [5s][5s][5s][5s][5s][5s][5s]...
                        ↓   ↓   ↓   ↓   ↓   ↓   ↓
Bumblebee processes:   [--------30s--------]
                            [--------30s--------]
                                 [--------30s--------]
                         (5s overlap)  (5s overlap)
```

**Key insight:** AudioChunker's 5-second chunks are simply the **feed rate**. Bumblebee accumulates them into 30-second windows with 5-second overlap, ensuring **no context loss** and good sentence boundary handling.

### Chunking Configuration

**AudioChunker (Membrane Filter):**

```elixir
child(:chunker, %AudioChunker{
  chunk_duration: Membrane.Time.seconds(5)  # Feed rate
})
```

**Bumblebee Serving:**

```elixir
Bumblebee.Audio.speech_to_text_whisper(
  whisper, featurizer, tokenizer, generation_config,
  chunk_num_seconds: 30,      # Processing window (Whisper internal)
  context_num_seconds: 5,     # Overlap for context preservation
  stream: true,               # Progressive output as chunks complete
  defn_options: [compiler: EXLA]
)
```

### Context Preservation & Sentence Boundaries

**How context is preserved:**

1. **Overlapping windows:** 5-second overlap means boundaries are processed twice
2. **Attention mechanism:** Whisper's transformer "looks back" at context
3. **Language modeling:** Whisper uses linguistic priors for sentence structure
4. **Merging logic:** Bumblebee intelligently merges overlapping transcriptions

**Sentence boundary handling:**

- Whisper processes 30-second segments (plenty for complete sentences)
- 5-second overlap (~10-20 words) provides strong context at boundaries
- Transformer attention captures long-range dependencies
- With `timestamps: :segments`, Whisper identifies natural speech breaks
- Quality depends on natural pauses in speech

**Expected quality:**

- ✅ Words rarely split mid-syllable
- ✅ Sentences generally respected at boundaries
- ✅ Context preserved across chunks
- ⚠️ Very long sentences (>30s) may have minor issues

### Alternative Chunking Strategies

**Current approach (recommended for first iteration):**

- Simple, proven pattern
- Good balance of latency and quality
- Works well for console output

**Future enhancements:**

1. **VAD-Based Chunking** (best quality)

   ```
   PortAudio → VAD Filter → Chunk at silences → WhisperSink
   ```

   - Chunk at natural speech pauses
   - Perfect sentence boundaries
   - More complex implementation
   - Requires Silero VAD or similar model

2. **Larger Chunks + More Overlap** (lower latency impact)

   ```elixir
   # AudioChunker
   chunk_duration: Membrane.Time.seconds(10)

   # Bumblebee
   chunk_num_seconds: 30,
   context_num_seconds: 8
   ```

   - Fewer chunk boundaries
   - More context at overlaps
   - Higher latency between outputs

3. **Full Recording Processing** (simplest)

   ```
   PortAudio → File.Sink → [stop recording] → Process complete file
   ```

   - No chunking boundaries at all
   - Perfect context
   - No progressive output
   - Best for short recordings

## Pipeline Lifecycle & External Control

### How to Stop Recording

**Answer: Second button press terminates the pipeline.**

The recording session lifecycle matches the pipeline lifecycle:

- **Button Press 1:** Create and start new pipeline
- **Button Press 2:** Gracefully terminate pipeline
- Audio device automatically released on termination

### Control Architecture

**Chosen Pattern: Pipeline-per-Recording**

Create a new Membrane pipeline for each recording session, terminate it when done.

**Why this approach:**

- **Simplest implementation:** Leverages Membrane's built-in lifecycle
- **Clean resource management:** Audio device released when not recording
- **Crash isolation:** Recording failure doesn't affect controller
- **Proven pattern:** Used by Membrane RTC Engine for recording endpoints
- **Acceptable latency:** 50-200ms pipeline startup imperceptible for button press

**Why NOT other patterns:**

- ❌ Dynamic children removal: More complex, unnecessary for simple start/stop
- ❌ Gate filter: Not idiomatic Membrane, processes buffers even when paused
- ❌ Custom controllable source: Overkill, PortAudio.Source doesn't support pause

### Component Responsibilities

#### RecordingController (GenServer)

- Load Whisper model **once** at application startup (~10-30s)
- Track recording state (recording: boolean, pipeline_pid)
- Create new pipeline on button press (pass pre-loaded serving)
- Monitor pipeline for crashes
- Terminate pipeline on second button press
- Handle transcription callbacks from pipeline

#### StreamingSTTPipeline (Membrane.Pipeline)

- Initialize PortAudio.Source (16kHz, mono, s16le)
- Route: PortAudio → AudioChunker → WhisperSink
- Optional: Tee branch to File.Sink for debugging
- Emit transcription chunks to controller callback
- Clean up resources on graceful termination

### Control Flow

```
Button Press 1 (Start)
    ↓
RecordingController.start_recording()
    ↓
Pipeline.start_link(StreamingSTTPipeline, whisper_serving: serving)
    ↓
Process.monitor(pipeline_pid)
    ↓
PortAudio begins capturing → AudioChunker → WhisperSink
    ↓
Transcription chunks sent to controller callback
    ↓ (progressive output during recording)

Button Press 2 (Stop)
    ↓
RecordingController.stop_recording()
    ↓
Pipeline.terminate(pipeline_pid, blocking: true)
    ↓
Pipeline sends EOS downstream → elements flush buffers
    ↓
PortAudio.Source closes audio device
    ↓
Pipeline terminates normally
    ↓
Controller receives :DOWN message
    ↓
Recording state reset
```

### Key Code Patterns

**Starting Recording:**

```elixir
def handle_call(:start_recording, _from, %{recording: false} = state) do
  {:ok, _supervisor_pid, pipeline_pid} =
    StreamingSTTPipeline.start_link(
      whisper_serving: state.serving,
      callback_pid: self()
    )

  Process.monitor(pipeline_pid)

  {:reply, :ok, %{state |
    recording: true,
    pipeline_pid: pipeline_pid,
    started_at: System.monotonic_time()
  }}
end
```

**Stopping Recording:**

```elixir
def handle_call(:stop_recording, _from, %{recording: true} = state) do
  # Graceful termination - pipeline flushes all buffers
  :ok = Membrane.Pipeline.terminate(state.pipeline_pid, blocking: true, timeout: 5000)

  duration = System.monotonic_time() - state.started_at
  Logger.info("Recording stopped", duration_ms: div(duration, 1_000_000))

  {:reply, :ok, %{state | recording: false, pipeline_pid: nil}}
end
```

**Handling Pipeline Crashes:**

```elixir
def handle_info({:DOWN, _ref, :process, pipeline_pid, reason}, state) do
  case reason do
    :normal ->
      Logger.info("Pipeline terminated normally")
    {:shutdown, _} ->
      Logger.info("Pipeline shutdown gracefully")
    _error ->
      Logger.error("Pipeline crashed", reason: inspect(reason))
  end

  {:noreply, %{state | recording: false, pipeline_pid: nil}}
end
```

**Receiving Transcriptions:**

```elixir
def handle_info({:transcription, text}, state) do
  IO.puts("Transcription: #{text}")
  # Future: Send to display, save to database, publish to Phoenix PubSub, etc.
  {:noreply, state}
end
```

### Benefits of This Approach

✅ **Matches button interaction model:** Explicit start/stop semantics
✅ **Simplest possible implementation:** No complex state management
✅ **Guaranteed resource cleanup:** Audio device released automatically
✅ **Model efficiency:** Whisper loaded once, reused across all recordings
✅ **Crash isolation:** Each recording session independent
✅ **OTP-idiomatic:** Proper supervision tree integration
✅ **Fast enough:** 50-200ms startup imperceptible to users
✅ **Clear state:** No ambiguity about whether recording is active

### Supervision Strategy

```
Application.Supervisor
    ↓
RecordingController (GenServer)
    ↓ (creates, monitors, terminates)
StreamingSTTPipeline (Membrane.Pipeline, temporary)
```

**Key points:**

- Controller is supervised `:permanent` (restart on crash)
- Pipeline is supervised `:temporary` (don't restart)
- Controller monitors pipeline for completion/crashes
- Pipeline has its own internal Membrane supervisor
- Recording sessions are user-initiated, not auto-restarted

### Model Selection for RPi

- **Recommended:** `openai/whisper-tiny` (39M params, ~150MB, ~500MB-1GB RAM, ~2-5s per 30s chunk on RPi4)
- **Alternative:** `openai/whisper-base` (better accuracy, 2x slower)
- **Avoid:** `whisper-large` (too large for RPi memory)

## Implementation Phases

**Phase 1: Core Components**

1. `AudioChunker` filter (accumulate/emit chunks)
2. `WhisperSink` (tensor conversion + Bumblebee integration)

**Phase 2: Pipeline**
3. `StreamingSTTPipeline` (wire PortAudio → Chunker → Sink)
4. Test with file source before live mic

**Phase 3: Controller & Lifecycle**
5. `RecordingController` GenServer

- Load Whisper model once at startup
- Create/terminate pipeline on button press
- Monitor pipeline, handle crashes
- Track recording state

6. Button integration with MoodBot

**Phase 4: Optimization** (future)
7. VAD for silence detection
8. Progressive output refinement
9. Error handling and recovery

## File Structure

```
lib/mood_bot/
  stt/
    recording_controller.ex       # GenServer managing lifecycle (NEW)
    streaming_stt_pipeline.ex     # Main Membrane pipeline
    audio_chunker.ex              # Custom filter for chunking
    whisper_sink.ex               # Custom sink for Bumblebee
    whisper.ex                    # Existing - can be basis for serving init
```

## Key Design Decisions

1. **No resampling needed:** PortAudio config (s16le, 16kHz, mono) matches Whisper expectations
2. **Two-level chunking:** AudioChunker (5s feed rate) + Bumblebee (30s processing with 5s overlap)
3. **Context preservation:** Overlapping windows ensure no context loss at boundaries
4. **Progressive output:** `stream: true` for near-real-time results
5. **Model loading:** Once at startup (~10-30s), kept in memory throughout lifecycle
6. **Pipeline lifecycle:** Pipeline-per-recording pattern (create on start, terminate on stop)
7. **Button control:** Second button press gracefully terminates pipeline

## Dependencies

**Required (already present):**

- ✅ `membrane_portaudio_plugin`, `membrane_file_plugin`
- ✅ `bumblebee`, `nx`, `exla`

**NOT required:**

- ❌ `membrane_mp3_lame_plugin` (only for MP3 encoding - safe to remove if unused)

## mp3_lame dependency

```shell
==> membrane_mp3_lame_plugin
Bundlex: Building natives: encoder
warning: Bundlex: Couldn't load OS dependency using {:precompiled, nil}

ignored, no URL provided

Loading using :pkg_config


could not compile dependency :membrane_mp3_lame_plugin, "mix compile" failed. Errors may have been logged above. You can recompile this dependency with "mix deps.compile membrane_mp3_lame_plugin --force", update it with "mix deps.update membrane_mp3_lame_plugin" or clean it with "mix deps.clean membrane_mp3_lame_plugin"
==> mood_bot
** (Mix) Bundlex: Couldn't load OS dependency :mp3lame of package membrane_mp3_lame_plugin. Make sure to follow installation instructions that may be available in the readme of membrane_mp3_lame_plugin.

Tried the following providers:

Provider `{:precompiled, nil}` ignored, no URL provided
Provider `:pkg_config` couldn't load ["mp3lame"] libraries with pkg-config due to:
        ** (BundlexError) pkg-config error:
        Code: 1
        Package mp3lame was not found in the pkg-config search path.
        Perhaps you should add the directory containing `mp3lame.pc'
        to the PKG_CONFIG_PATH environment variable
        Package 'mp3lame', required by 'virtual:world', not found
```

## Considerations & Risks

**Performance (RPi4):**

- Memory: ~500MB-1GB for whisper-tiny
- Latency: ~2-5s per 30s audio segment
- Model loading: 10-30s at startup
- Mitigation: Use whisper-tiny, load at app start

**Audio quality:**

- USB mics preferred over built-in
- Background noise affects accuracy
- Future: Add VAD to skip silence

**Error handling:**

- Model failures (EXLA, OOM)
- Audio device issues (disconnect, permissions)
- Pipeline crashes
- Mitigation: Supervision trees, detailed logging

## Expected Outcome

1. Button press → recording starts
2. Audio streams through Membrane pipeline
3. Whisper processes 30s windows with 5s overlap
4. Transcription appears progressively on console
5. Button press → recording stops

## References & Resources

### Official Examples & Documentation

- **[Membrane Demo: Speech-to-Text](https://github.com/membraneframework/membrane_demo/tree/master/livebooks/speech_to_text)** - Official Livebook showing Membrane + Bumblebee Whisper integration
- **[Bumblebee Phoenix Example: speech_to_text.exs](https://github.com/elixir-nx/bumblebee/blob/main/examples/phoenix/speech_to_text.exs)** - Phoenix LiveView with Whisper
- **[Membrane Tutorial: Custom Filters](https://membrane.stream/learn/get_started_with_membrane/3)** - How to create custom Membrane elements
- **[Livebook: Whisper Improvements](https://news.livebook.dev/speech-to-text-with-whisper-timestamping-streaming-and-parallelism-oh-my---launch-week-2---day-2-36osSY)** - New streaming features in Bumblebee

### Tutorials & Blog Posts

- **[DockYard: Audio Speech Recognition in Elixir with Whisper Bumblebee](https://dockyard.com/blog/2023/03/07/audio-speech-recognition-in-elixir-with-whisper-bumblebee)** - Comprehensive Whisper setup guide
- **[Real-Time Voice Transcription with Elixir Nx: A Practical Guide](https://medium.com/@marinakrasnovatr81/real-time-voice-transcription-with-elixir-nx-a-practical-guide-3d455d330783)** - Phoenix Channels + Whisper streaming
- **[Underjord: Voice Activity Detection in Elixir and Membrane](https://underjord.io/voice-activity-detection-elixir-membrane.html)** - VAD with Membrane + ONNX (excellent custom filter example)
- **[Lucas Sifoni: Hello Bumblebee, Hello Whisper!](https://lucassifoni.info/blog/hello-bumblebee-hello-whisper/)** - Introduction to Whisper in Elixir
- **[Lucas Sifoni: Distributed transcription with Whisper and Elixir](https://lucassifoni.info/blog/distributed-transcription-with-elixir-whisper/)** - Scaling Whisper processing

### Community Resources

- **[Elixir Forum: Membrane and Whisper Audio](https://elixirforum.com/t/membrane-and-whisper-audio/57732)** - Discussion on integration
- **[Elixir Forum: Resample for Bumblebee Whisper](https://elixirforum.com/t/resample-8000hz-s16le-for-use-in-bumblebee-whisper-model-16000hz-32f/56018)** - Audio format conversion help
- **[Elixir Forum: Support for high-quality microphone](https://elixirforum.com/t/support-for-high-quality-microphone/68076/6)** - Nerves audio setup
- **[Elixir Forum: The Grand Kiosk (reTerminal with Nerves)](https://elixirforum.com/t/project-the-grand-kiosk-the-seeed-studio-reterminal-dm-with-nerves/66321)** - Real-world Nerves audio project
- **[Elixir Forum: High memory usage with whisper-large-v3](https://elixirforum.com/t/high-memory-usage-when-transcribing-with-whisper-large-v3-in-nx-exla-bumblebee/71614)** - Memory optimization tips

### Advanced Topics

- **[Membrane Demo: OpenAI Realtime with WebRTC](https://github.com/membraneframework/membrane_demo/tree/master/openai_realtime_with_membrane_webrtc)** - Low-latency AI conversations
- **[Elixir Forum: OpenAI Realtime Integration](https://elixirforum.com/t/openai-realtime-integration-with-membrane-webrtc/69344)** - Discussion on real-time AI audio
- **[Membrane WebRTC Components](https://hexdocs.pm/membrane_webrtc_plugin/Membrane.WebRTC.Live.html)** - WebRTC LiveView components
- **[Boombox Examples](https://github.com/membraneframework/boombox/blob/master/examples.livemd)** - High-level Membrane API examples

### GitHub Issues & Discussions

- **[Bumblebee #261: Stream audio chunk by chunk to Whisper](https://github.com/elixir-nx/bumblebee/issues/261)** - Streaming audio discussion
- **[Underjord VAD Gist](https://gist.github.com/lawik/df61c7d37939df1258a67fa4b7573a49)** - Complete VAD implementation code

### Documentation

- **[HexDocs: Bumblebee.Audio](https://hexdocs.pm/bumblebee/Bumblebee.Audio.html)** - Audio processing functions
- **[HexDocs: Nx.Serving](https://hexdocs.pm/nx/Nx.Serving.html)** - Serving infrastructure
- **[HexDocs: Membrane.PortAudio](https://hexdocs.pm/membrane_portaudio_plugin/Membrane.PortAudio.html)** - PortAudio plugin docs
- **[HexDocs: Membrane.Filter](https://hexdocs.pm/membrane_core/Membrane.Filter.html)** - Filter behavior docs
- **[HexDocs: Membrane.Sink](https://hexdocs.pm/membrane_core/Membrane.Sink.html)** - Sink behavior docs
