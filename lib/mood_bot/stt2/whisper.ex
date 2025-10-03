defmodule MoodBot.STT2.Whisper do
  @moduledoc """
  Whisper speech-to-text transcription using Bumblebee.
  """

  require Logger

  @doc """
  Loads Whisper serving configured for progressive transcription during recording.

  ## Configuration
  - `chunk_num_seconds: 30` - Processing window size
  - `context_num_seconds: 5` - Overlap between windows (prevents word splitting)
  - `stream: true` - Enable progressive output

  ## Returns
  `{:ok, serving}` with configured Nx.Serving for streaming
  """
  def load_streaming_serving do
    Logger.info("Loading Whisper model for streaming transcription...")

    with {:ok, model_info} <- Bumblebee.load_model({:hf, "openai/whisper-tiny"}),
         {:ok, featurizer} <- Bumblebee.load_featurizer({:hf, "openai/whisper-tiny"}),
         {:ok, tokenizer} <- Bumblebee.load_tokenizer({:hf, "openai/whisper-tiny"}),
         {:ok, generation_config} <-
           Bumblebee.load_generation_config({:hf, "openai/whisper-tiny"}) do
      serving =
        Bumblebee.Audio.speech_to_text_whisper(
          model_info,
          featurizer,
          tokenizer,
          generation_config,
          language: "de",
          chunk_num_seconds: 30,
          context_num_seconds: 5,
          stream: true,
          defn_options: [compiler: EXLA]
        )

      Logger.info("Whisper streaming serving loaded successfully")
      {:ok, serving}
    else
      {:error, reason} = error ->
        Logger.error("Failed to load Whisper model: #{inspect(reason)}")
        error
    end
  end
end
