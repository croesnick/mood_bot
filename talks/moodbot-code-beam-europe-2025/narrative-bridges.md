# Narrative Bridges & Transitions

## Purpose

This document provides the "glue" between slides and acts - the transition sentences and phrases that maintain narrative flow and weave the vibe coding theme throughout the talk.

---

## Opening (Slide 1 → Slide 2)

**After title slide, pause, then:**
> "This is a story about a question, a lot of late nights, and discovering that the Elixir ecosystem is far more powerful than I expected."

---

## Act I: The Spark (Slides 2-4)

### Slide 2 → Slide 3 Transition

**After showing the 2022 robotic arm and son's drawings:**
> "We built this together - it moved, it looked cool. But my son wanted more. He wanted a robot he could *talk to*. One that would *understand him* and *respond*."
>
> **[Show son's drawings briefly]**
>
> "He even drew the robot faces he imagined - happy, sad, surprised. These became the five moods MoodBot displays. That made it real for me - I wasn't just building a robot, I was bringing his drawings to life."
>
> "And that... felt impossible."

### Slide 3 → Slide 4 Transition

**After showing the gap:**
> "But something changed in 2025. The rise of AI coding assistants - specifically Claude Code and Model Context Protocol servers - gave me confidence. Maybe with vibe coding and limited time, I *could* tackle this."
>
> "And then I looked at what Elixir's ecosystem had become..."

### Slide 4 Closing (Act I → Act II Transition)

**After showing the tools:**
> "So I had the tools, the motivation, and just enough confidence. Time to build."
>
> "Here's what I learned about making ideas real..."

---

## Act II: The Build (Slides 5-7.6, then 8)

### Weaving "Vibe Coding" Throughout Act II

#### Slide 5 (E-Ink: Visual First) - Vibe Coding Excitement & Reality Check

**Opening energy:**
> "I started visual-first. E-Ink display - show the mood immediately."

**Vibe coding excitement:**
> "I was using hexdocs MCP - Claude Code could look up Elixir docs. SSH MCP - test directly on the device. I got ambitious: *what if Claude Code could see what's on the E-Ink through a webcam MCP?* Visual debugging!"

**Reality hits:**
> "Hit a wall trying to make E-Ink work. Tried spec-driven development - documentation frenzy. Backed out. Baby steps instead."

**The crucible moment:**
> "Line-by-line debugging. 5am on a TechDay. Comparing Python and Elixir side-by-side. One wrong hex command. *One*."
>
> **[Show emotion]**: "But when I found it... and the screen lit up... I sent a video to my son immediately."

**Key lesson woven in:**
> "This taught me: **back out what you can't explain**. Spec-driven created more than I could understand. Baby steps won."

#### Slide 6 (Image Pipeline) - Pragmatic Debugging Infrastructure

**Ambitious vision:**
> "Next: image pipeline. On-device vision processing. My son could hold a drawing to the camera, transformed and cropped, stored as a new mood."

**MockHAL as essential infrastructure:**
> "VIX struggles led me to build something critical: MockHAL. ASCII rendering in terminal. PBM files saved to tmp. Not just convenience - **essential debugging infrastructure**."
>
> **[Brief mention]**: "Same codebase, two implementations: MockHAL for laptop development, RpiHAL for production."

**Cross-compilation reality:**
> "Then cross-compilation nightmares. VIX and NX refused to build for ARM from Apple Silicon. GitHub issue rabbit holes. Pinning versions."
>
> "Solution? Build VM. Slowed feedback loop, but it *worked*."

**Pragmatic decision:**
> "In the end: host preprocessing. Not the on-device dream, but *it works*. Pragmatism over purity."

#### Slide 7 (Scope & Focus) - Dropping Features Aggressively

**Opening:**
> "All this taught me to pick minimal scope early. Drop features aggressively."

**Examples woven naturally:**
> "The webcam MCP vision system? Cool idea, dropped. On-device image processing? Too ambitious for V1. Baby steps."

**Lesson:**
> "Focus on the core: Can my son talk to MoodBot? Can MoodBot understand and respond? Everything else is nice-to-have."

### Slide 7 → Slide 7.5 Transition

**After showing scope decisions:**
> "Scope focused. Now: make it speak. Audio first..."

### Slide 7.5 (Audio Wins) - Simple Solutions Win

**Opening:**
> "Audio. I started with TTS - text to speech."

**Quick win:**
> "Looked at Bumblebee for on-device TTS. Found issue #209 immediately - no TTS support yet. Fine. Azure Speech API for a quick win. Proves feasibility, worry about on-device later."

**The pleasant surprise:**
> "Then audio output. I was expecting to need Membrane, complex pipelines... tried aplay and amixer first. Just simple shell commands."
>
> "It worked. Can make sound? Check. Can speak German? Check. Baby step complete."

### Slide 7.5 → Slide 7.6 Transition

**After audio wins:**
> "Audio worked. Now to make it smart..."

### Slide 7.6 (AI Assembly & Button) - Bringing It All Together

**Opening:**
> "Three models I wanted to run: Whisper for speech recognition, German-Emotions for sentiment, and SmolLM2 for responses. Three large models, concurrently, on a Raspberry Pi."

**The button question:**
> "But how do you trigger it? The mic can't record all the time. Simple: a button."

**Father-son teaching moment:**
> "This became a perfect teaching moment with my son. We built an Arduino test circuit together - button to LED. He's learning electronics. I'm testing debouncing and interrupt handling."

**Architecture emerges:**
> "And here's where the complete pipeline emerged: Button press starts recording. Whisper transcribes. Sentiment analysis determines mood. E-Ink shows the mood. SmolLM2 generates response. Azure TTS speaks it back."

**Elixir elegance (technical showcase):**
> "Audio processing in Elixir looks like this:" *[Show binary pattern matching code]* "One line. Binary pattern matching - embedded work feeling natural.
>
> But here's the key: **each model is its own supervised process**. Whisper crashes? Only Whisper restarts. Sentiment keeps analyzing. **This is why I chose Elixir** - fault isolation for AI workloads.
>
> And all these workloads running concurrently - no threading complexity, no mutex debugging. BEAM's preemptive scheduler just handles it."

### Slide 7.6 → Slide 8 Transition

**After complete pipeline:**
> "That's the architecture. But does it actually work? Let me show you..."

---

## Act II → Act III Transition (Slide 8 → Slide 9)

**After the demo video:**
> "After months of small wins, debugging sessions, and dropped features, MoodBot came alive."
>
> **[Pause for effect]**
>
> "Here's what I'd tell my past self... and what I hope you'll take away."

---

## Act III: Reflection (Slides 9-11)

### Slide 9 (Lessons Learned) - Vibe Coding Synthesis

**During the lessons:**

**On scope:**
> "Pick minimal scope early. Drop features aggressively. The webcam MCP vision system sounded cool - but it wasn't the core experience."

**On iteration:**
> "Baby steps beat big specs. I used Claude for GenServer boilerplate, but reviewed every piece I didn't understand. When Claude generated something I couldn't explain? I backed it out."
>
> **[Reference Ghostty quote]**: "Mitchell Hashimoto calls this 'vibe coding' - and I violated it with the E-Ink driver. Learned that lesson the hard way at 5am."

**On ecosystem:**
> "Lean on mature libraries. Membrane made audio feel like magic. Bumblebee made ML serving just... work. VintageNet handled networking complexity I didn't have to think about."

### Slide 9 → Slide 10 Transition

**After lessons:**
> "The ecosystem got me this far. But there's still frontier ahead - places where *you* can help shape the future..."

### Slide 10 → Slide 11 Transition

**After showing frontiers:**
> "But here's the thing - you don't need everything perfect to start."
>
> **[Build energy]**: "The ecosystem is ready *now*."

---

## Closing (Slide 11)

### Final Message

**Deliver the core takeaway:**
> "Elixir's ecosystem has quietly grown powerful enough to bring AI and hardware together."
>
> "You can build real robots now - starting on your laptop, deploying to a Pi, without leaving Elixir."

**Actionable closing:**
> "Pick a Raspberry Pi. Choose Membrane for audio. Try Bumblebee for ML. Use the MockHAL pattern for development. Build something small. Iterate."
>
> **[Show MoodBot video callback]**
>
> "And maybe, like me, you'll answer your kid's question: 'Can we have a robot?'"
>
> "Yes. Yes, we can build one."

### Slide 11 → Slide 12 Transition

**Simple, warm:**
> "Thank you. I'm happy to take your questions."

---

## Emotional Pacing Guide

### Energy Levels Across the Talk

```
Slide 1 (Title):           [Calm, warm opening]
Slide 2 (Spark):           [Build emotional connection]
Slide 3 (Gap):             [Slight tension - the challenge]
Slide 4 (Tools):           [Rising hope - the discovery]
Slide 5 (E-Ink):           [Excitement → struggle → breakthrough!]
Slide 6 (Image Pipeline):  [Ambitious → pragmatic - building infrastructure]
Slide 7 (Scope):           [Learning moment - humble, focused]
Slide 7.5 (Audio Wins):    [Pleasant surprise - simple wins]
Slide 7.6 (AI Assembly):   [Building energy → TECHNICAL PEAK - elegance!]
Slide 8 (Demo):            [EMOTIONAL PEAK - it works!]
Slide 9 (Lessons):         [Reflective, sharing wisdom]
Slide 10 (Frontiers):      [Forward-looking, invitational]
Slide 11 (Takeaway):       [Inspirational high - call to action]
Slide 12 (Q&A):            [Open, approachable]
```

### Key Emotional Beats

1. **Connection** (Slides 2-3): Father-son relationship, son's drawings make aspiration concrete
2. **Hope** (Slide 4): Discovery of tools that make it possible
3. **Excitement** (Slide 5 opening): Vibe coding tools - webcam MCP ambition!
4. **Struggle** (Slide 5): 5am debugging - authentic difficulty, spec-driven failure
5. **Breakthrough** (Slide 5): Screen lights up - video to son
6. **Pragmatism** (Slide 6): MockHAL infrastructure, host preprocessing compromise
7. **Focus** (Slide 7): Drop features, baby steps wisdom
8. **Simple Wins** (Slide 7.5): Audio just works - validation
9. **Technical Pride** (Slide 7.6): Father-son moment + Elixir elegance showcase
10. **Joy** (Slide 8): Working system, son interaction - PEAK
11. **Invitation** (Slides 10-11): You can do this too

---

## Backup Transitions (If Running Short on Time)

### Quick Act I → Act II
>
> "The tools existed. Time to build."

### Quick Act II → Act III
>
> "It works. Here's what I learned."

### Quick Slide 7 → Slide 7.5
>
> "Now: make it speak."

### Quick Slide 7.5 → Slide 7.6
>
> "Audio worked. Now the AI."

### Quick Slide 7.6 → Slide 8
>
> "That's the architecture. Watch it in action."

---

## Vibe Coding Theme - Complete Arc

**Introduction** (implicit in Slide 4):

- AI coding assistants gave me confidence
- MCP tools (hexdocs, SSH) enable new workflows

**Excitement** (Slide 5 opening):

- hexdocs MCP, SSH MCP working beautifully
- Got ambitious: webcam MCP for visual debugging!

**Reality Check** (Slide 5):

- Claude wrote the driver, but I debugged for 5 hours (5am)
- Spec-driven development → documentation frenzy
- **Lesson**: Back out what you can't explain

**Pragmatic Building** (Slide 6):

- MockHAL as essential debugging infrastructure
- Host preprocessing over on-device purity
- Build VM to solve cross-compilation

**Learning - Focus** (Slide 7):

- Drop features aggressively (webcam MCP, on-device vision)
- Baby steps beat big specs
- Pick minimal scope early

**Simple Wins** (Slide 7.5):

- aplay/amixer "just worked"
- Azure TTS for quick win (Bumblebee gap)
- Prove feasibility before complexity

**Technical Elegance** (Slide 7.6):

- Binary pattern matching, process isolation, concurrent orchestration
- Father-son Arduino moment (human touch)
- "This is why I chose Elixir" - tools + thought

**Synthesis** (Slide 9):

- "Automate the right things, keep thinking about the rest"
- Review what you don't understand, back it out if needed
- Claude for boilerplate ✅, but think about architecture

**Takeaway** (Slide 11):

- The ecosystem enables you to build real things
- You still need to think, iterate, understand
- Vibe coding + baby steps = sustainable progress

**Message**: Vibe coding is powerful when paired with thoughtful iteration. AI assistants are tools, not replacements for understanding.

---

## Timing Recommendations

- **Act I** (Slides 1-4): 4-5 minutes
- **Act II** (Slides 5-8): 11-13 minutes (includes 30-45s demo)
  - Slide 5 (E-Ink): 2-3 min
  - Slide 6 (Image Pipeline): 2 min
  - Slide 7 (Scope): 90s
  - Slide 7.5 (Audio Wins): 90s
  - Slide 7.6 (AI Assembly): 2-3 min
  - Slide 8 (Demo): 60-90s
- **Act III** (Slides 9-11): 4-5 minutes
  - Slide 9 (Lessons): 2 min
  - Slide 10 (Frontiers): 1-2 min
  - Slide 11 (Takeaway): 1-2 min
- **Q&A** (Slide 12): Remaining time

**Total talk time**: ~19-23 minutes (13 slides) + Q&A

**Target**: Aim for 20 minutes to leave buffer

**Buffer**: Build in 2-3 minutes buffer for audience reactions, laughter, or technical issues
