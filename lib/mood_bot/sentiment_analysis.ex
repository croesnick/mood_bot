defmodule MoodBot.SentimentAnalysis do
  @moduledoc """
  German emotion classification using XLM-RoBERTa.

  Classifies German text into MoodBot's sentiment categories using the
  ChrisLalk/German-Emotions model, which recognizes 28 emotions from the
  German GoEmotions dataset.

  MoodBot sentiment categories:
  - `:happy` - Positive, joyful (joy, amusement, excitement, optimism, love)
  - `:affirmation` - Agreeable, supportive, neutral (approval, caring, gratitude, admiration, pride, relief, neutral, curiosity, realization)
  - `:skeptic` - Doubtful, irritated (annoyance, disappointment, disapproval, embarrassment)
  - `:surprised` - Unexpected, confused (surprise, confusion)
  - `:angry` - Angry, disgusted (anger, disgust)
  - `:crying` - Sad, negative (sadness, grief, remorse, fear, nervousness, desire)
  """

  use GenServer
  require Logger

  @model_repo {:hf, "ChrisLalk/German-Emotions"}
  @serving_name __MODULE__.Serving

  @typedoc "MoodBot sentiment categories"
  @type sentiment :: :happy | :affirmation | :skeptic | :surprised | :angry | :crying

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Analyzes the emotion of German text.

  Returns one of MoodBot's five sentiment categories based on emotion classification.
  Uses the ChrisLalk/German-Emotions model which classifies into 28 emotions,
  then maps to one of the 5 MoodBot sentiments.
  """
  @spec analyze(String.t()) :: {:ok, sentiment()} | {:error, term()}
  def analyze(text) when is_binary(text) do
    try do
      %{predictions: predictions} = Nx.Serving.batched_run(@serving_name, text)
      sentiment = map_predictions_to_sentiment(predictions)
      {:ok, sentiment}
    rescue
      error ->
        Logger.error("SentimentAnalysis: Analysis failed", error: error)
        {:error, {:analysis_failed, error}}
    end
  end

  # GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("SentimentAnalysis: Loading German Emotions model")

    case load_model() do
      {:ok, serving_pid} ->
        Logger.info("SentimentAnalysis: Model loaded successfully")
        {:ok, %{serving_pid: serving_pid}}

      {:error, reason} ->
        Logger.error("SentimentAnalysis: Failed to load model", error: reason)
        {:stop, reason}
    end
  end

  # Private Functions

  defp load_model do
    with {:ok, model_info} <- Bumblebee.load_model(@model_repo),
         {:ok, tokenizer} <- Bumblebee.load_tokenizer(@model_repo) do
      serving = Bumblebee.Text.text_classification(model_info, tokenizer)

      Nx.Serving.start_link(
        name: @serving_name,
        serving: serving
      )
    end
  end

  @spec map_predictions_to_sentiment(list(map())) :: sentiment()
  defp map_predictions_to_sentiment(predictions) do
    # Get highest scoring emotion from the 28 GoEmotions categories
    top_emotion_entry =
      predictions
      |> Enum.max_by(& &1.score)

    top_emotion = String.downcase(top_emotion_entry.label)
    top_score = top_emotion_entry.score

    sorted_predictions =
      predictions
      |> Enum.sort_by(& &1.score, :desc)
      |> Enum.map(fn %{label: label, score: score} ->
        "#{label}: #{:erlang.float_to_binary(score * 100, decimals: 2)}%"
      end)
      |> Enum.join(", ")

    Logger.debug("All emotions: #{sorted_predictions}")

    # Map 28 emotions to 5 MoodBot sentiments
    result =
      case top_emotion do
        # Happy emotions: joy, amusement, excitement, optimism, love
        label when label in ["joy", "amusement", "excitement", "optimism", "love"] ->
          :happy

        # Affirmation emotions: approval, caring, gratitude, admiration, pride, relief,
        # neutral (factual statements), curiosity (questions), realization (acknowledging facts)
        label
        when label in [
               "approval",
               "caring",
               "gratitude",
               "admiration",
               "pride",
               "relief",
               "neutral",
               "curiosity",
               "realization"
             ] ->
          :affirmation

        # Skeptic/irritated emotions: annoyance, disappointment, disapproval, embarrassment
        label when label in ["annoyance", "disappointment", "disapproval", "embarrassment"] ->
          :skeptic

        # Surprised/confused emotions: surprise, confusion (narrowed to only true unexpected emotions)
        label when label in ["surprise", "confusion"] ->
          :surprised

        # Angry/disgusted emotions: anger, disgust
        label when label in ["anger", "disgust"] ->
          :angry

        # Crying/sad emotions: sadness, grief, remorse, fear, nervousness, desire
        label
        when label in [
               "sadness",
               "grief",
               "remorse",
               "fear",
               "nervousness",
               "desire"
             ] ->
          :crying

        # Unmatched emotions default to affirmation
        _ ->
          :affirmation
      end

    Logger.info("Mapped to MoodBot sentiment: #{result}")
    result
  end
end
