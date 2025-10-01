defmodule MoodBot.STT.Whisper do
  @moduledoc """
  Whisper speech-to-text transcription using Bumblebee.
  """

  require Logger

  @doc """
  Child specification for supervision tree.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 5000
    }
  end

  @doc """
  Starts the Whisper serving process.
  Uses Whisper Tiny model for fast transcription.
  """
  def start_link(_opts) do
    {:ok, model_info} = Bumblebee.load_model({:hf, "openai/whisper-tiny"})
    {:ok, featurizer} = Bumblebee.load_featurizer({:hf, "openai/whisper-tiny"})
    {:ok, tokenizer} = Bumblebee.load_tokenizer({:hf, "openai/whisper-tiny"})
    {:ok, generation_config} = Bumblebee.load_generation_config({:hf, "openai/whisper-tiny"})

    serving =
      Bumblebee.Audio.speech_to_text_whisper(
        model_info,
        featurizer,
        tokenizer,
        generation_config,
        language: "de",
        defn_options: [compiler: EXLA]
      )

    Nx.Serving.start_link(name: __MODULE__, serving: serving)
  end

  @doc """
  Transcribes audio from a file path.
  Expects raw s16le PCM audio at 16kHz mono.
  Returns the transcribed text.
  """
  def transcribe_file(file_path) do
    Logger.info("Transcribing audio file: #{file_path}")

    # Read raw PCM binary
    {:ok, binary} = File.read(file_path)

    # Convert s16le → f32 normalized samples
    samples = for <<sample::signed-little-16 <- binary>>, do: sample / 32768.0

    # Create 1D Nx tensor
    tensor = Nx.tensor(samples, type: :f32)

    # Pass tensor directly to serving
    result = Nx.Serving.batched_run(__MODULE__, tensor)

    # Extract text from chunks
    text =
      result.chunks
      |> Enum.map(& &1.text)
      |> Enum.join("")

    Logger.info("Transcription complete", text: text)
    {:ok, text}
  end
end
