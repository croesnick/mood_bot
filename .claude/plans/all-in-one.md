# Combine Everything

We now got all the essential components set up for MoodBot:

- `lib/mood_bot/display`: E-Ink driver and display abstraction to print to the e-ink screen.
  There's also the functionality to print monochrome pictures on the screen.
  In particular, we can show my son's very nice mood drawings: `<root>/assets/moods`.
- `lib/mood_bot/stt`: We can record the user's speech and transcribe it using a local-running Whisper model.
  The transcription is embedded into a Membrane pipeline.
  The recording should start at button press and stop on a second button press.
  Expected and supported language is German.
- `lib/mood_bot/language_models`: Given the transcript of the user's speech, we want to generate a good response.
  To this end, we use Small Language Models (SLMs) also running locally on the RPi.
  Given a good and refined system prompt and the user's transcript, the SLM generates a response for the user.
  Goal is to be helpful, kind, understanding.
  All the conversation should keep in mind that the target audience are children in the age range 6 to 12.
- `lib/mood_bot/sentiment_analysis.ex`: Given the user's transcript, we show a robot face on the e-ink display matching the mood of the current state of the conversation.
  The robot faces will be taken from `<root>/assets/moods`.
- `lib/mood_bot/tts`: Given the generated response, we use the Azure Cloud to generate a voice output via the speakers connected to the RPi.

## Integration Plan

### Architecture Decisions

#### 1. Controller Pattern (Simple, Iteration 1)

- **Single orchestrator**: `MoodBot.Controller` GenServer
- **Sequential pipeline**: Each step completes before next begins
- **Well-behaved user assumption**: User presses button, waits for entire pipeline to complete
- **Future iterations**: Add interrupt handling, request queuing, concurrent operation management

#### 2. State Management

- **In-memory conversation history**: Store messages in Controller GenServer state
- **History structure**: List of `%{role: :user | :assistant, content: String.t()}`. TODO: Check the Bumblebee/LLM API docs.
- **Future enhancement**: Persist history to device partition, load on boot (not implemented yet)

#### 3. GPIO Button Integration

- **Library**: Use Circuits library for GPIO access
- **Pin selection**: TBD - needs recommendation for RPi 5
- **Separate plan**: Create `.claude/plans/button-gpio.md` for detailed GPIO integration
- **Debouncing**: Handle in GPIO plan

#### 4. Pipeline Flow

```plaintext
[Button Press 1]
    ↓
[Start Recording] → [1 minute timeout OR Button Press 2]
    ↓
[Stop Recording & Transcribe]
    ↓
[Analyze Sentiment] → [Display Mood Face] (during LLM processing)
    ↓
[Generate LLM Response] (using conversation history + system prompt)
    ↓
[TTS Output + Display Update] (concurrent)
    ↓
[Return to Idle]
```

#### 5. Timing & Synchronization

- **Mood face display**: AFTER transcription and based on its output, DURING LLM processing
- **TTS and display update**: Concurrent (both start at same time)
- **Recording timeout**: 1 minute (60 seconds) if no stop button press
- **Timeout behavior**: Auto-stop and process transcription

#### 6. Error Handling Strategy

- **Log all errors**: Use Logger with context
- **Display error mood**: Show robot face with "dead eyes" (`robot-face-error.pbm` -- assume it exists, will be added by me later)
- **Return to idle**: Don't crash, continue operation
- **Conversation preserved**: History maintained even on errors

#### 7. System Prompt

- **Configuration**: Hardcoded in `MoodBot.Controller` module attribute
- **Placeholder**: Placeholder string with TODO comment for now
- **User provides later**: Will be filled in by user at later stage
- **Language**: German
- **Audience**: Children aged 6-12
- **Tone**: Helpful, kind, understanding, age-appropriate

### Components Status

✅ **MoodBot.Display**: E-ink display with image rendering
✅ **MoodBot.STT.Manager**: Button-triggered recording + transcription
✅ **MoodBot.SentimentAnalysis**: German emotion → 5 sentiment categories
✅ **MoodBot.LanguageModels.Api**: Text generation with streaming support
✅ **MoodBot.TTS.Runner**: Azure TTS with audio playback
✅ **Mood Images**: `assets/moods/robot-face-happy.pbm` (others will be added by me)

### Implementation Tasks

1. **Create `MoodBot.Controller` GenServer**
   - State machine: `:idle`, `:recording`, `:processing`, `:responding`, `:error`
   - Conversation history storage (in-memory)
   - Simple starter system prompt module attribute with TODO placeholder

2. **Implement Pipeline Orchestration**
   - Button press → `STT.Manager.start_recording()`
   - Second press or timeout → stop recording
   - Transcription → `SentimentAnalysis.analyze/1`
   - Display mood face during LLM processing
   - Generate response with `LanguageModels.Api.generate/3`
   - Concurrent: TTS via `TTS.Runner.speak/1` + display update
   - Return to `:idle`

3. **Mood Face Image Integration**
   - Map sentiment atoms to `.pbm` file paths
   - Load and display images via `Display.display_image/1`
   - Handle missing images gracefully -- via a placeholder image
   - Sentiments: `:happy`, `:affirmation`, `:skeptic`, `:surprised`, `:crying`, `:error`

4. **Error Handling & Recovery**
   - Wrap each pipeline step with monadic error handling
   - On error: log, display error mood, return to `:idle`
   - Preserve conversation history
   - Don't crash on individual step failures

5. **Recording Timeout**
   - Schedule `Process.send_after/3` for 60 seconds
   - Cancel timer on manual stop
   - Auto-stop and process on timeout
   - Handle race conditions (timer vs manual stop)

6. **Add to Supervision Tree**
   - Add `{MoodBot.Controller, []}` to `application.ex`
   - Place after all dependencies (Display, STT, LLM, Sentiment)
   - Both host and target configurations

7. **Create Missing Mood Face Images**
   - Need placeholder `.pbm` files for:
     - `robot-face-affirmation.pbm`
     - `robot-face-skeptic.pbm`
     - `robot-face-surprised.pbm`
     - `robot-face-crying.pbm`
     - `robot-face-error.pbm`
   - Keep existing `robot-face-happy.pbm`

8. **Create Button GPIO Plan**
   - New file: `.claude/plans/button-gpio.md`
   - GPIO pin recommendations for RPi 5
   - Circuits library integration details
   - Debouncing strategy
   - Integration with Controller

9. **Update README**
   - Document Controller API
   - Briefly explain pipeline flow
   - Note future iteration plans
   - No usage examples; it's still an MVP

### Not Implemented (Future Iterations)

- ❌ Conversation history persistence to disk
- ❌ Interrupt handling (button during processing)
- ❌ Request queuing for concurrent users
- ❌ Sophisticated concurrency management
- ❌ Performance monitoring
- ❌ Actual GPIO button integration (separate plan)

### Success Criteria

After `mix upload` to RPi:

- ✅ System boots and enters idle state
- ✅ Button press starts recording
- ✅ Second press or 1-min timeout stops and processes
- ✅ Mood face displays based on sentiment
- ✅ LLM generates German response for children
- ✅ TTS speaks response through speakers
- ✅ Conversation history maintained across interactions
- ✅ Errors handled gracefully without crashes
- ✅ System returns to ready state after each interaction
- ✅ Works on both host (development) and target (RPi)
