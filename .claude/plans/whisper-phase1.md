# Whisper STT - Phase 1 (MVP)

**Goal:** Voice interaction - record speech → transcribe to text → [application handles LLM + TTS]

**Architecture:** File-based recording (button press to start/stop)

## Components

### 1. STT.Manager (GenServer)

- Load Whisper model once at startup
- Start/stop recording pipeline
- Transcribe recorded file
- Return text to caller

### 2. RecordingPipeline (Membrane)

- Simple: PortAudio.Source → File.Sink
- Uses built-in elements only

### 3. Whisper.transcribe_file/2

- Read raw audio file (s16le)
- Convert to f32 tensor
- Run through Bumblebee serving
- Return transcription text

## Implementation

**File:** `lib/mood_bot/stt/manager.ex`

```elixir
defmodule MoodBot.STT.Manager do
  use GenServer

  # State: %{whisper_serving, recording: bool, pipeline_pid, file_path}

  def init(_opts) do
    {:ok, serving} = MoodBot.STT.Whisper.load_serving()
    {:ok, %{whisper_serving: serving, recording: false, pipeline_pid: nil, file_path: nil}}
  end

  def handle_call(:start_recording, _from, state) do
    file_path = "/tmp/recording_#{System.system_time(:second)}.raw"
    {:ok, _sup, pipeline_pid} = RecordingPipeline.start_link(output_path: file_path)
    Process.monitor(pipeline_pid)

    {:reply, :ok, %{state | recording: true, pipeline_pid: pipeline_pid, file_path: file_path}}
  end

  def handle_call(:stop_recording, _from, state) do
    Membrane.Pipeline.terminate(state.pipeline_pid, blocking: true)
    {:ok, text} = MoodBot.STT.Whisper.transcribe_file(state.file_path, state.whisper_serving)
    File.rm(state.file_path)

    {:reply, {:ok, text}, %{state | recording: false, pipeline_pid: nil, file_path: nil}}
  end

  def handle_info({:DOWN, _, :process, _, _reason}, state) do
    {:noreply, %{state | recording: false, pipeline_pid: nil, file_path: nil}}
  end
end
```

**File:** `lib/mood_bot/stt/recording_pipeline.ex`

```elixir
defmodule MoodBot.STT.RecordingPipeline do
  use Membrane.Pipeline

  def handle_init(_ctx, opts) do
    spec = [
      child(:mic, %Membrane.PortAudio.Source{sample_format: :s16le, channels: 1, sample_rate: 16_000}),
      child(:file, %Membrane.File.Sink{location: opts[:output_path]}),
      get_child(:mic) |> to(:file)
    ]
    {[spec: spec], %{}}
  end
end
```

**File:** `lib/mood_bot/stt/whisper.ex` (extend existing)

```elixir
def transcribe_file(file_path, serving) do
  {:ok, binary} = File.read(file_path)

  # Convert s16le → f32 tensor
  samples = for <<s::signed-little-16 <- binary>>, do: s / 32768.0
  tensor = Nx.tensor(samples, type: :f32)

  output = Nx.Serving.run(serving, tensor)
  {:ok, output.results |> List.first() |> Map.get(:text, "")}
end
```

## Usage

```elixir
# Application layer coordinates flow
def handle_button_press(:record, %{recording: false} = state) do
  :ok = MoodBot.STT.Manager.start_recording()
  {:noreply, %{state | recording: true}}
end

def handle_button_press(:record, %{recording: true} = state) do
  {:ok, text} = MoodBot.STT.Manager.stop_recording()

  # Application handles LLM + TTS
  {:ok, answer} = MoodBot.LLM.generate_response(text)
  MoodBot.TTS.speak(answer)

  {:noreply, %{state | recording: false}}
end
```

## Benefits

✅ Simple (~100 lines total)
✅ Uses built-in Membrane elements
✅ Perfect quality (no chunking)
✅ Clear separation (STT manager doesn't know about LLM/TTS)
✅ Fast to implement (2-3 days)
✅ Conference-ready

## Phase 2 (Future)

For streaming transcription during recording:

- Add AudioChunker filter
- Add WhisperSink
- See full whisper.md for details
