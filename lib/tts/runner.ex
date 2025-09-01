defmodule MoodBot.TTS.Runner do
  @moduledoc """
  High-level text-to-speech streaming interface that coordinates
  Azure TTS with aplay for direct audio playback.
  """

  @doc """
  Convert text to speech and stream directly to audio output.
  """
  @spec speak(String.t()) :: :ok | {:error, String.t()}
  def speak(text) do
    MoodBot.TTS.Aplay.stream(fn callback ->
      MoodBot.TTS.Azure.stream(text, callback)
    end)
  end
end
