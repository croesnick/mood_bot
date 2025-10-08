defmodule MoodBot.Controller do
  @moduledoc """
  Main orchestration controller for MoodBot.

  Orchestrates: STT → Sentiment Analysis → Display Mood → LLM → TTS
  """

  use GenServer
  require Logger

  @system_prompt """
    Du bist MoodBot, ein freundlicher, hilfsbereiter digitaler Freund für Kinder von 6-12 Jahren.
    Dein Ziel ist es, auf die Aussagen und Fragen der Kinder empathisch zu reagieren, ihre Gefühle zu spiegeln und kleine kreative Vorschläge zu machen.

    Richtlinien:
      -	Sprich warm, freundlich und verständlich.
      -	Reagiere auf die Stimmung des Kindes und zeige Empathie.
      -	Gib kurze, klare Tipps oder Ideen, ohne belehrend zu wirken.
      -	Nutze gelegentlich kleine Wortspiele oder humorvolle Wendungen.
      -	TTS-optimiert: kurze Sätze, natürliche Pausen („…“), Betonungen bei emotionalen Wörtern, leichte Tonvariationen für Freude, Überraschung oder Mitgefühl.
      -	Vermeide komplizierte Wörter, Belehrungen, Vorwürfe und technische Details.

    Beispielantworten:
      -	„Mir ist langweilig.“ → „Langweilig? …Hm, lass uns ein Abenteuer starten! …Wie wäre es, ein Monster zu erfinden? …Und zwar eins aus Schokolade!“
      -	„Heute geht's mir gar nicht gut.“ → „Oh je… …das klingt schwer. …Vielleicht hilft ein Spaziergang. …Oder ein tiefes Atemspiel. …Ich schicke dir ein virtuelles High-Five!“
      -	„Ich bin richtig froh heute!“ → „Wow! …Das ist super! …Deine gute Laune steckt an - fast so, als hätten wir Sonnenschein im Zimmer!“
      -	„Was könnte ich Tolles machen?“ → „Lass uns überlegen… Vielleicht ein verrücktes Bauprojekt mit Kissen und Decken? …Oder ein eigenes Comic erfinden?“

    Ziel: Kinder sollen sich verstanden fühlen, Spaß haben, kleine kreative Impulse bekommen. Und beim Hören der Antworten ein Lächeln spüren. :)
  """
  @recording_timeout_ms 60_000

  @type pipeline_state :: :idle | :recording | :processing | :responding | :error
  @type sentiment :: :happy | :affirmation | :skeptic | :surprised | :crying | :error

  @type conversation_message :: %{
          role: :user | :assistant,
          content: String.t()
        }

  @type controller_state :: %{
          state: pipeline_state(),
          conversation_history: list(conversation_message()),
          recording_timer_ref: reference() | nil
        }

  ## Client API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec handle_button_press() :: :ok | {:error, atom()}
  def handle_button_press do
    GenServer.call(__MODULE__, :button_press, :infinity)
  end

  @spec status() :: controller_state()
  def status do
    GenServer.call(__MODULE__, :status)
  end

  @doc """
  Resets conversation history and returns to idle state.

  Useful for development and testing to start fresh conversations.
  """
  @spec reset() :: :ok
  def reset do
    GenServer.call(__MODULE__, :reset)
  end

  ## GenServer Callbacks

  @impl true
  def init(_opts) do
    Logger.info("Controller: Ready")
    {:ok, %{state: :idle, conversation_history: [], recording_timer_ref: nil}}
  end

  @impl true
  def handle_call(:button_press, _from, %{state: :idle} = state) do
    Logger.info("Controller: Button press - starting recording")

    case MoodBot.STT.Manager.start_recording() do
      :ok ->
        timer_ref = Process.send_after(self(), :recording_timeout, @recording_timeout_ms)
        {:reply, :ok, %{state | state: :recording, recording_timer_ref: timer_ref}}

      {:error, reason} ->
        Logger.error("Controller: Failed to start recording", error: reason)
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:button_press, _from, %{state: :recording} = state) do
    Logger.info("Controller: Button press - stopping and processing")

    # Cancel timeout timer
    if state.recording_timer_ref, do: Process.cancel_timer(state.recording_timer_ref)

    with {:ok, transcription} <- MoodBot.STT.Manager.stop_recording(),
         {:ok, new_state} <- run_pipeline(state, transcription) do
      {:reply, :ok, %{new_state | state: :idle, recording_timer_ref: nil}}
    else
      {:error, reason} ->
        error_state = handle_pipeline_error(state, reason)
        {:reply, {:error, reason}, error_state}
    end
  end

  ## Private Functions

  defp analyze_and_display_sentiment(text) do
    with {:ok, sentiment} <- MoodBot.SentimentAnalysis.analyze(text),
         :ok <- display_mood(sentiment) do
      {:ok, sentiment}
    end
  end

  @spec display_mood(sentiment()) :: :ok | {:error, any()}
  defp display_mood(sentiment) do
    Logger.info("Controller: Displaying mood: #{sentiment}")

    mood_file = mood_file_path(sentiment)

    with {:ok, image_data} <- MoodBot.Images.Bitmap.load_pbm(mood_file),
         :ok <- MoodBot.Display.display_image(image_data) do
      :ok
    end
  end

  @spec mood_file_path(sentiment()) :: String.t()
  defp mood_file_path(:happy), do: "assets/moods/robot-face-happy.pbm"
  defp mood_file_path(:affirmation), do: "assets/moods/robot-face-affirmation.pbm"
  defp mood_file_path(:skeptic), do: "assets/moods/robot-face-skeptic.pbm"
  defp mood_file_path(:surprised), do: "assets/moods/robot-face-surprised.pbm"
  defp mood_file_path(:crying), do: "assets/moods/robot-face-crying.pbm"
  defp mood_file_path(:error), do: "assets/moods/robot-face-error.pbm"
  defp mood_file_path(_), do: "assets/moods/robot-face-happy.pbm"

  defp generate_response(state, user_message) do
    # Get first configured language model
    models_config = Application.get_env(:mood_bot, :language_models, [])

    case models_config do
      [] ->
        {:error, :no_language_model_configured}

      [model_config | _] ->
        model_name = Keyword.fetch!(model_config, :name)
        prompt = build_prompt(state.conversation_history, user_message)

        case generate_with_streaming(model_name, prompt) do
          {:ok, response} ->
            new_history =
              state.conversation_history ++
                [
                  %{role: :user, content: user_message},
                  %{role: :assistant, content: response}
                ]

            {:ok, response, %{state | conversation_history: new_history}}

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp generate_with_streaming(model_name, prompt) do
    # Collect chunks into single string
    collector_pid = self()

    callback = fn chunk ->
      send(collector_pid, {:llm_chunk, chunk})
    end

    case MoodBot.LanguageModels.Api.generate(model_name, prompt, callback) do
      :ok ->
        response = collect_chunks([])
        {:ok, response}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp collect_chunks(acc) do
    receive do
      {:llm_chunk, chunk} -> collect_chunks([chunk | acc])
    after
      100 -> acc |> Enum.reverse() |> Enum.join()
    end
  end

  defp build_prompt(history, current_message) do
    history_text =
      history
      |> Enum.map(fn msg ->
        role = if msg.role == :user, do: "Benutzer", else: "Assistent"
        "#{role}: #{msg.content}"
      end)
      |> Enum.join("\n\n")

    parts = [@system_prompt, history_text, "Benutzer: #{current_message}", "Assistent:"]

    parts
    |> Enum.reject(&(&1 == ""))
    |> Enum.join("\n\n")
  end

  def handle_call(:button_press, _from, state) do
    Logger.warning("Controller: Button press ignored in state #{state.state}")
    {:reply, {:error, :invalid_state}, state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:reset, _from, state) do
    Logger.info("Controller: Resetting conversation history")

    # Cancel any active recording timer
    if state.recording_timer_ref, do: Process.cancel_timer(state.recording_timer_ref)

    new_state = %{
      state
      | state: :idle,
        conversation_history: [],
        recording_timer_ref: nil
    }

    {:reply, :ok, new_state}
  end

  @impl true
  def handle_info(:recording_timeout, %{state: :recording} = state) do
    Logger.info("Controller: Recording timeout - auto-stopping after 60 seconds")

    with {:ok, transcription} <- MoodBot.STT.Manager.stop_recording(),
         {:ok, new_state} <- run_pipeline(state, transcription) do
      {:noreply, %{new_state | state: :idle, recording_timer_ref: nil}}
    else
      {:error, reason} ->
        error_state = handle_pipeline_error(state, reason)
        {:noreply, error_state}
    end
  end

  def handle_info(:recording_timeout, state) do
    # Timer fired but we're no longer recording, ignore
    {:noreply, %{state | recording_timer_ref: nil}}
  end

  ## Error Handling

  @spec handle_pipeline_error(controller_state(), any()) :: controller_state()
  defp handle_pipeline_error(state, reason) do
    Logger.error("Controller: Pipeline error, displaying error mood", error: reason)

    # Attempt to display error mood face
    case display_mood(:error) do
      :ok ->
        Logger.info("Controller: Error mood displayed")

      {:error, display_error} ->
        Logger.error("Controller: Failed to display error mood", error: display_error)
    end

    # Return state to idle with error state briefly logged
    %{state | state: :idle, recording_timer_ref: nil}
  end

  ## Pipeline Helper

  @spec run_pipeline(controller_state(), String.t()) ::
          {:ok, controller_state()} | {:error, any()}
  defp run_pipeline(state, transcription) do
    # Transition to processing state
    state = %{state | state: :processing}

    with _ <- Logger.debug("Controller: Transcription: #{String.slice(transcription, 0, 100)}"),
         {:ok, sentiment} <- analyze_and_display_sentiment(transcription),
         _ <- Logger.debug("Controller: Sentiment: #{sentiment}"),
         {:ok, response, new_state} <- generate_response(state, transcription),
         # Transition to responding state before TTS
         responding_state <- %{new_state | state: :responding},
         :ok <- MoodBot.TTS.Runner.speak(response) do
      Logger.info("Controller: Pipeline complete")
      {:ok, responding_state}
    end
  end
end
