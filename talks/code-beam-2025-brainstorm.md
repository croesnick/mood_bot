# Brainstorm Talk Content & Structure

## Brainstorm

- `RingLogger.attach`
- Nerves OTA updates
- MCP hype train, causing me to initially aim to use or build all kinds of MCPs (docs, ssh, webcam, image normalization)
- Vibing my way through the project
  - [How HashiCorp co-founder and father of Ghostty "vibe codes"](https://mitchellh.com/writing/non-trivial-vibing)
    Interesting aspect:
    > If the agent figures it out and I don't understand it, I back it out.
    I violated that, especially when vibing the Waveshare E-Ink driver o:)
- Almost all of the code was written or touched at some point by Claude Code (4 -> 4.1 -> 4.5)
- Vibe coding journey and lessons
  - Claude Code wrote the E-Ink driver... but I spent 5 hours debugging one wrong hex command line-by-line (5am start!)
  - Spec-Driven Development created documentation frenzy - switched to baby-step iteration
  - New approach: GenServer base structure → init → one feature at a time, digestible by me
  - "Automate the right things, keep thinking about the rest" - used Claude for boilerplate, reviewed everything I didn't understand
  - Also tried Spec-Driven Development at some point, but it turned out to be meh. My tasks where probably just too big? At least it created so, so much writeup before it actually started _doing_ things.
  - interesting new ref: <https://github.com/github/spec-kit>
- Switch to build VM due to cross-compilation problems with vix and nx
  - link here to the attempts to improve cross-compilation
- TTS: Using Azure Speech API (cloud-based) because Bumblebee doesn't support TTS yet
  - Early 2024: Currently, there aren't native Elixir text-to-speech AI tools available, though the infrastructure (via Nx and Bumblebee) exists to potentially support them in the future.
    <https://elixirforum.com/t/are-there-any-text-to-speech-ai-tools-available-using-elixir/70047/2>
  - Late 2024: Support for TTS in Bumblebee has been requested, but is not there yet.
    <https://github.com/elixir-nx/bumblebee/issues/209>
  - Current workaround: Azure Speech API via HTTP + aplay for audio output
  - Trade-off: On-device STT/LLM/Sentiment analysis but cloud TTS (internet dependency)
  - This is a key "Frontier" item: completing the fully on-device AI robot experience
- Local inference currently rather limited so just "some" models; no e.g. gemma or deepseek yet
- The HAILO HAT is aiming to provide greatly improved inference, but it's not there yet
- Small test circuit building using an Arduino o:) for fast iteration and interactivity with my son
- Image render pipeline
  - aimed for on-demand image conversion on device via vix, but (due to cross-compilation issues) decided to do that on the host and just ship the final images as assets with the device image
- How well porting the E-Ink driver went
  - video about my first successful render
  - changes to be made in the architecture compared to the Python version
- Audio processing
  - first aimed for [xav](https://github.com/elixir-webrtc/xav) for direct and no additional layers audio processing using ffmpeg.
  - but then, after a few articles about the componentized architecture, aimed for membrane
- Complete interaction pipeline architecture (MoodBot.Controller)
  - Button press → STT (Whisper on-device, German) → Sentiment Analysis (German-Emotions model) → Mood Display (E-Ink) → LLM Response (SmolLM2 on-device, child-friendly) → TTS (Azure Cloud API)
  - Trade-offs: On-device ML for privacy/speed, cloud TTS for quality until Bumblebee supports it
  - All in German with child-friendly system prompt (ages 6-12)
  - 5 mood states mapping: happy, affirmation, skeptic, surprised, crying
  - 60-second recording timeout, automatic sentiment-to-mood mapping
- MockHAL development workflow
  - Enabled full development on MacBook without any hardware
  - Saves PBM bitmap images to visualize what would display on E-Ink
  - Logs all SPI writes and GPIO operations for debugging
  - Same codebase runs on host (MockHAL) and target (RpiHAL) - true hardware abstraction
  - Pattern worth sharing with embedded community
- > The future of software engineering does not belong to those who automate everything. Instead, it belongs to those who automate the right things and keep thinking about the rest.
  From: <https://davidadamojr.com/ai-generated-tests-are-lying-to-you/>
- quick dive into the components of Nerves: packages, deployment workflow (build firmware, upload)

## Didactic Approach

5 Ws: Ask why we need a feature or what's the required knowledge to understand the point I am trying to make.
Repeat until hitting a base.

## Slides

- son has a thing with robots -> photos (museum, arm, ...)
- rise of vibe coding, CC and other tools, MCPs -> I have almost no time, but maybe I can still build something? Maybe not a moving robot interatcting with the environment... but something to interact with in a smaller way?
- start with hardware: take RPi, add e-ink display. wanted to build a small firmware from scratch in Elixir to see how it feels. found waveshare e-ink (affordable, Python reference implementation). journey to port it.
- was a hassle. show it. somehow :S maybe show the vibing part (i've got an example) with docs + ssh mcp
  - long debugging session to find the issue -> cc wasn't able to find it
- then introduce the pictures drawn by my son. wanted to display them on the e-ink, but also have a debugging MockHAL to run on the host for debugging. show the png->pbm pipeline (everyone loves ascii art)
