defmodule MoodBot.STT.Manager do
  @moduledoc """
  Coordinates audio recording and speech-to-text transcription.
  """

  use GenServer
  require Logger

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def start_recording do
    GenServer.call(__MODULE__, :start_recording)
  end

  def stop_recording do
    GenServer.call(__MODULE__, :stop_recording, 30_000)
  end

  # Server Callbacks

  @impl true
  def init(_opts) do
    {:ok, %{recording: false, pipeline_pid: nil, file_path: nil}}
  end

  @impl true
  def handle_call(:start_recording, _from, %{recording: false} = state) do
    file_path = "/tmp/recording_#{System.system_time(:second)}.raw"

    {:ok, _sup, pipeline_pid} =
      Membrane.Pipeline.start_link(MoodBot.STT.RecordingPipeline, file_path)

    Process.monitor(pipeline_pid)

    Logger.info("Started recording to #{file_path}")

    {:reply, :ok, %{state | recording: true, pipeline_pid: pipeline_pid, file_path: file_path}}
  end

  @impl true
  def handle_call(:start_recording, _from, %{recording: true} = state) do
    {:reply, {:error, :already_recording}, state}
  end

  @impl true
  def handle_call(:stop_recording, _from, %{recording: true} = state) do
    Membrane.Pipeline.terminate(state.pipeline_pid)

    {:ok, text} = MoodBot.STT.Whisper.transcribe_file(state.file_path)
    File.rm(state.file_path)

    Logger.info("Transcription: #{text}")

    {:reply, {:ok, text}, %{state | recording: false, pipeline_pid: nil, file_path: nil}}
  end

  @impl true
  def handle_call(:stop_recording, _from, %{recording: false} = state) do
    {:reply, {:error, :not_recording}, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) do
    Logger.warning("Recording pipeline terminated: #{inspect(reason)}")
    {:noreply, %{state | recording: false, pipeline_pid: nil, file_path: nil}}
  end
end
