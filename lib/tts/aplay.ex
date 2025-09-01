defmodule MoodBot.TTS.Aplay do
  @doc """
  Stream audio data from a data source function to aplay.
  """
  @spec stream(function()) :: :ok | {:error, String.t()}
  def stream(data_source) do
    with {:ok, :ready} <- ensure_audio_ready() do
      port = open_aplay_port()
      data_source.(fn data -> Port.command(port, data) end)
      Port.close(port)
      :ok
    end
  end

  @doc """
  Ensure the audio system is ready for playback by setting volume.
  """
  @spec ensure_audio_ready() :: {:ok, :ready} | {:error, String.t()}
  def ensure_audio_ready do
    case System.cmd("amixer", ["set", "PCM", "100%"], stderr_to_stdout: true) do
      {_output, 0} ->
        {:ok, :ready}

      {error_output, _exit_code} ->
        {:error, "Failed to configure audio: #{error_output}"}
    end
  end

  # Open aplay as an Erlang port that accepts binary data on stdin
  defp open_aplay_port() do
    Port.open({:spawn_executable, "/usr/bin/aplay"}, [
      :binary,
      :exit_status,
      # aplay arguments: quiet mode, read from stdin
      {:args, ["-q", "-"]},
      # Don't use packets, just raw binary stream
      :stream
    ])
  end
end
