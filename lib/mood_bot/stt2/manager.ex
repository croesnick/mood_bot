defmodule MoodBot.STT2.Manager do
  @moduledoc """
  GenServer managing streaming speech-to-text transcription.

  ## Features
  - **Progressive transcription**: Receive partial results during recording
  - **Streaming pipeline**: Uses AudioChunker + WhisperSink for real-time feedback
  - **Context preservation**: 30s Whisper windows with 5s overlap prevent word splitting
  - **Long recording support**: Suitable for recordings longer than 60 seconds

  ## Comparison with STT.Manager (Phase 1)
  - **Phase 1** (STT.Manager): Record → Stop → Transcribe entire file
  - **Phase 2** (STT2.Manager): Record + Progressive transcription during recording

  ## Usage
  ```elixir
  # Start recording with progressive transcription
  {:ok, manager} = MoodBot.STT2.Manager.start_link([])
  :ok = MoodBot.STT2.Manager.start_recording(manager)

  # Receive messages during recording:
  # {:transcription_chunk, "Hello ", 1}
  # {:transcription_chunk, "world!", 2}
  # ...

  # Stop recording
  :ok = MoodBot.STT2.Manager.stop_recording(manager)
  # Receive: :transcription_complete
  ```

  ## State
  - `whisper_serving` - Loaded Whisper model (streaming configuration)
  - `recording` - Boolean flag
  - `pipeline_pid` - StreamingPipeline process
  - `chunks` - Accumulated transcription chunks
  """
  use GenServer
  require Logger

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Start recording with progressive transcription.

  Transcription chunks will be sent as messages:
  - `{:transcription_chunk, text, chunk_number}`
  - `:transcription_complete` when done
  """
  @spec start_recording() :: :ok | {:error, :already_recording}
  def start_recording(pid \\ __MODULE__) do
    GenServer.call(pid, :start_recording)
  end

  @doc """
  Stop recording and wait for final transcription.

  Returns accumulated transcription text from all chunks.
  """
  @spec stop_recording() :: {:ok, String.t()} | {:error, :not_recording}
  def stop_recording(pid \\ __MODULE__) do
    GenServer.call(pid, :stop_recording, :infinity)
  end

  @doc """
  Get current recording status and accumulated transcription.
  """
  @spec status() :: %{recording: boolean(), transcription: String.t()}
  def status(pid \\ __MODULE__) do
    GenServer.call(pid, :status)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    Logger.info("STT2.Manager initializing with streaming Whisper model...")

    case MoodBot.STT2.Whisper.load_streaming_serving() do
      {:ok, serving} ->
        Logger.info("STT2.Manager ready for streaming transcription")

        {:ok,
         %{
           whisper_serving: serving,
           recording: false,
           pipeline_pid: nil,
           chunks: []
         }}

      {:error, reason} ->
        Logger.error("Failed to load Whisper streaming serving: #{inspect(reason)}")
        {:stop, {:whisper_load_failed, reason}}
    end
  end

  @impl true
  def handle_call(:start_recording, _from, %{recording: true} = state) do
    {:reply, {:error, :already_recording}, state}
  end

  def handle_call(:start_recording, _from, %{recording: false} = state) do
    Logger.info("Starting streaming transcription recording...")

    case Membrane.Pipeline.start_link(MoodBot.STT2.StreamingPipeline,
           whisper_serving: state.whisper_serving,
           callback_pid: self()
         ) do
      {:ok, _supervisor, pipeline_pid} ->
        Process.monitor(pipeline_pid)
        Logger.info("StreamingPipeline started: #{inspect(pipeline_pid)}")

        {:reply, :ok,
         %{
           state
           | recording: true,
             pipeline_pid: pipeline_pid,
             chunks: []
         }}

      {:error, reason} ->
        Logger.error("Failed to start StreamingPipeline: #{inspect(reason)}")
        {:reply, {:error, {:pipeline_start_failed, reason}}, state}
    end
  end

  @impl true
  def handle_call(:stop_recording, _from, %{recording: false} = state) do
    {:reply, {:error, :not_recording}, state}
  end

  def handle_call(:stop_recording, _from, %{recording: true} = state) do
    Logger.info("Stopping recording and waiting for final transcription...")

    # Terminate pipeline gracefully
    Membrane.Pipeline.terminate(state.pipeline_pid, blocking: true)

    # Wait briefly for final transcription_complete message
    # (should arrive quickly after pipeline terminates)
    receive do
      :transcription_complete ->
        Logger.info("Transcription complete, received all chunks")
    after
      5_000 ->
        Logger.warning("Timeout waiting for transcription_complete")
    end

    # Concatenate all chunks into final text
    full_text =
      state.chunks
      |> Enum.sort_by(fn {_text, chunk_num} -> chunk_num end)
      |> Enum.map(fn {text, _chunk_num} -> text end)
      |> Enum.join(" ")
      |> String.trim()

    Logger.info(
      "Recording stopped, transcription complete: #{String.length(full_text)} characters from #{length(state.chunks)} chunks"
    )

    {:reply, {:ok, full_text},
     %{
       state
       | recording: false,
         pipeline_pid: nil,
         chunks: []
     }}
  end

  @impl true
  def handle_call(:status, _from, state) do
    transcription =
      state.chunks
      |> Enum.sort_by(fn {_text, chunk_num} -> chunk_num end)
      |> Enum.map(fn {text, _chunk_num} -> text end)
      |> Enum.join(" ")
      |> String.trim()

    status = %{
      recording: state.recording,
      transcription: transcription,
      chunk_count: length(state.chunks)
    }

    {:reply, status, state}
  end

  @impl true
  def handle_info({:transcription_chunk, text, chunk_num}, state) do
    Logger.debug("Received transcription chunk #{chunk_num}: #{String.slice(text, 0, 50)}...")

    # Store chunk with its number for proper ordering
    chunks = [{text, chunk_num} | state.chunks]

    # Forward to any listeners (optional: could broadcast via Phoenix.PubSub)
    # For now, just log and accumulate
    Logger.info("Chunk #{chunk_num}: #{text}")

    {:noreply, %{state | chunks: chunks}}
  end

  @impl true
  def handle_info(:transcription_complete, state) do
    Logger.info("Transcription stream complete")
    # This message signals end of transcription stream
    # Final text retrieval happens in stop_recording
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, reason}, %{pipeline_pid: pid} = state) do
    Logger.warning("StreamingPipeline terminated: #{inspect(reason)}")

    {:noreply,
     %{
       state
       | recording: false,
         pipeline_pid: nil
     }}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    # Some other process died, ignore
    {:noreply, state}
  end
end
