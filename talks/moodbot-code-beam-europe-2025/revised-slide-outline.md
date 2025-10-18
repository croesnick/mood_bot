# MoodBot: Raising a Tiny Robot With Elixir, Nerves, and AI

## Complete Slide Outline - Code BEAM Europe 2025

**Speaker**: [Your Name]
**Duration**: 20 minutes + Q&A
**Audience**: Elixir developers, embedded systems enthusiasts, AI/ML practitioners

---

## Core Takeaway

> "Elixir's ecosystem has quietly grown powerful enough to bring AI and hardware together — you can build real robots now, starting on your laptop, deploying to a Pi, without leaving Elixir."

---

## Talk Structure

**Act I: The Spark** (Slides 1-4) - 4-5 minutes
**Act II: The Build** (Slides 5-8) - 10-12 minutes
**Act III: Reflection** (Slides 9-11) - 4-5 minutes
**Closing** (Slide 12) - Q&A

---

# Slide-by-Slide Breakdown

## Slide 1: Title

### Content

**Title**: MoodBot: Raising a Tiny Robot With Elixir, Nerves, and AI
**Subtitle**: A father-son project exploring AI, hardware, and the Elixir ecosystem
**Visual**: Photo of assembled MoodBot (E-Ink display showing a mood, Raspberry Pi visible)
**Footer**: Your name, Code BEAM Europe 2025

### Speaker Notes

- Warm, welcoming opening
- Pause after title slide appears
- Let audience settle in

### Opening Line (Transition to Slide 2)
>
> "This is a story about a question, a lot of late nights, and discovering that the Elixir ecosystem is far more powerful than I expected."

**Timing**: 30 seconds

---

## Slide 2: The Spark - "Can we have a robot?"

### Content

**Title**: The Spark: "Can we have a robot?"
**Visual**:
- Photo of the 2022 robotic arm (ROT3U 6DOF) that you built with your son
- **NEW**: 2-3 of your son's original robot face drawings (small inset or next slide transition)

**Text elements**:

- 2022: Built robotic arm with servos together
- Fun to build, fun to move
- But limited interaction
- "Dad, can I have a robot that talks to me?"

### Speaker Notes

**Story to tell**:

- Your son was 6 in 2022 when you built the arm
- He enjoyed it, but wanted more
- Wanted natural interaction - talking, understanding
- **NEW**: "He even drew the robot faces he imagined - happy, sad, surprised. These became the five moods MoodBot displays. That made it real for me - I wasn't just building a robot, I was bringing his drawings to life."
- That felt impossible at the time

### Key Points

- Establish emotional connection (father-son)
- Set up the problem (aspiration vs reality gap)
- Make it relatable to audience
- **NEW**: Son's drawings show concrete vision, not abstract aspiration

### Transition to Slide 3
>
> "We built this together - it moved, it looked cool. But my son wanted more. He wanted a robot he could *talk to*. One that would *understand him* and *respond*. And that... felt impossible."

**Timing**: 70-100 seconds (includes 5-10s for showing drawings)

---

## Slide 3: The Gap - Impossible or Out of Reach

### Content

**Title**: The Gap: Impossible or Out of Reach
**Visual**: Split screen or grid showing:

- Industrial robots (expensive, not conversational)
- Research robots (cutting-edge, unavailable)
- Consumer robots (limited, scripted responses)

**Text**:

- Commercial robots: Too expensive
- Natural interaction: Too complex
- Vision + Speech + AI: Felt out of reach
- 2022-2023: The gap seemed too wide

### Speaker Notes

- Acknowledge the challenge honestly
- This builds tension in the narrative
- Audience should feel "yeah, that IS hard"

### Key Points

- Don't oversimplify the challenge
- Make the eventual solution more impressive
- Contrast "dream vs reality"

### Transition to Slide 4
>
> "But something changed in 2024-2025. The rise of AI coding assistants - specifically Claude Code and Model Context Protocol servers - gave me confidence. Maybe with vibe coding and limited time, I *could* tackle this. And then I looked at what Elixir's ecosystem had become..."

**Timing**: 60 seconds

---

## Slide 4: The Tools That Changed Everything

### Content

**Title**: The Tools That Changed Everything
**Visual**: Logos arranged in a stack diagram:

- **Foundation**: Elixir + OTP
- **Hardware Layer**: Nerves, Circuits (GPIO/SPI), VintageNet
- **Audio/Media**: Membrane Framework
- **AI/ML**: Bumblebee, Nx, EXLA

**Text**:

- Nerves: Elixir on embedded devices
- Circuits: Hardware abstraction (GPIO, SPI)
- Membrane: Audio pipeline framework
- Bumblebee + Nx: ML model serving
- VintageNet: Modern networking
- All mature, production-ready

### Speaker Notes

- This is the "discovery" moment
- Emphasize maturity, not just existence
- These aren't toys - they're production tools

### Key Points

- Ecosystem milestone: tools are ready NOW
- You don't need Python or C++ for robotics
- Elixir can do embedded + AI

### Transition to Act II
>
> "So I had the tools, the motivation, and just enough confidence. Time to build. Here's what I learned about making ideas real..."

**Timing**: 60-90 seconds

---

# Act II: The Build

## Slide 5: E-Ink - Visual First

### Content

**Title**: E-Ink: Visual First
**Visual**:

- Photo of Waveshare 2.9" E-Ink display
- Split screen: Python driver code vs your Elixir port
- Screenshot: hexdocs MCP + SSH MCP in action
- Video: First successful E-Ink render (emotional payoff at end)

**Text**:

**Why E-Ink?**
- Wanted something visual immediately
- Waveshare 2.9": Easily available, Python driver sources, no Elixir driver
- Perfect DIY opportunity

**Development Setup:**
- MockHAL: Laptop development without hardware
- Same codebase, two implementations

**Vibe Coding Excitement:**
- hexdocs MCP: Claude Code looks up Elixir docs
- SSH MCP: Tests directly on device
- **Got ambitious**: webcam MCP for visual debugging!
  - "Claude Code could see what's on the E-Ink and help me debug!"

**Reality Check:**
- Hit wall trying to make E-Ink work
- Tried spec-driven development → documentation frenzy
- Backed out: baby steps instead
- Partial rewrite of vibe-coded driver
- Line-by-line debugging (5am crucible)
- **One wrong hex command**
- Relief finding the bug

### Speaker Notes

**Opening** (15s):
> "I wanted something visual. An E-Ink display seemed perfect - Waveshare had Python drivers, easily available, and no Elixir implementation. Perfect DIY opportunity."

**Vibe Coding Excitement** (30s):
> "I was excited about the tooling. hexdocs MCP meant Claude Code could look up Elixir documentation. SSH MCP meant it could test directly on the device. I got ambitious - what if I added a webcam MCP? Claude Code could *see* what's on the E-Ink and help me debug visually!"

**Reality Check** (45s):
> "Then I hit a wall. Couldn't make the E-Ink work. Tried Claude's spec-driven development workflow - pages of documentation before any code. I was generating faster than I could understand.
>
> Backed out. Took smaller steps. The vibe-coded driver needed a partial rewrite. Then came the 5am debugging session - line-by-line comparison of Python vs Elixir. One wrong hex command. *One*.
>
> But when I found it..." *[Video plays - first successful E-Ink render]*

**After video** (10s):
> "I sent this video to my son immediately. This moment taught me: vibe coding gives you code fast, but you still debug it yourself. Baby steps beat documentation frenzy."

### Video: E-Ink First Render

**Duration**: 5-8 seconds
**Placement**: After describing the bug discovery
**Purpose**: Emotional payoff - relief and excitement

### Key Points

- Webcam MCP ambition shows excitement about tools
- Hitting wall creates humility
- Spec-driven vs baby-step iteration (first mention)
- Vibe coding reality: Claude writes, you debug
- 5am crucible moment - persistence pays off

### Transition to Slide 6
>
> "The E-Ink worked. Now I wanted to push further - what else could I do on-device?"

**Timing**: 2-3 minutes (including 5-8s video)

---

## Slide 6: Image Pipeline - On-Device Vision

### Content

**Title**: Image Pipeline: On-Device Vision
**Visual**:

- Diagram showing camera → transform → BW → flash storage pipeline
- VIX cross-compilation error screenshot
- MockHAL output: ASCII rendering in terminal + PBM file example
- Code snippet: Build VM solution or MockHAL bitmap saving

**Text**:

**Ambitious Goal:**
- Everything on-device (not smart, just pushing limits)
- Future vision: Hold drawing to camera → transformed/cropped/BW → stored on flash → instant new mood face
- "My son could draw new moods!"

**VIX Journey:**
- Worked beautifully on host
- Cross-compilation nightmares for RPi target
- Build VM solution (reference from HAILO HAT community)

**MockHAL Extension:**
- ASCII rendering in terminal
- PBM file saving to tmp folder
- Not just convenience - **essential debugging infrastructure**
- Enabled testing drawing routines without hardware

**Pragmatic Decision:**
- Pre-process images on host
- Ship as assets with firmware
- On-device complexity not worth it for this use case

### Speaker Notes

**Opening** (15s):
> "The E-Ink worked. I wanted to push further - what else could I do on-device?"

**Ambitious Vision** (30s):
> "I had this vision: my son could hold a drawing up to a camera, and MoodBot would transform it - crop, convert to black and white, store it on flash. Instant new mood face! Everything on-device. Not because it's smart, but because pushing limits is fun."

**VIX Struggle** (30s):
> "Found VIX for image processing. Worked great on my Mac. Then tried building for the Raspberry Pi... cross-compilation nightmares. NIF loading failures, platform mismatches. Eventually solved it with a build VM - learned that from the HAILO HAT community."

**MockHAL Saves the Day** (30s):
> "But before that, I extended the MockHAL. It started rendering ASCII art in the terminal - you could see what would be on the E-Ink. Then it started saving PBM bitmap files. This wasn't just a development convenience. It was **essential debugging infrastructure**. I could test all the drawing routines without hardware."

**Pragmatism Wins** (15s):
> "In the end? I pre-process images on my host machine and ship them as assets. On-device image processing wasn't worth the complexity for this use case. Sometimes pragmatism beats ideology."

### Key Points

- Ambitious goals are good (they push you)
- Build debugging infrastructure early (MockHAL bitmaps)
- Pragmatism > ideology (host preprocessing won)
- Cross-compilation is real work (build VM solution)
- Father-son future vision (drawing new moods together)

### Transition to Slide 7
>
> "This taught me to be ruthless about scope. What's core? What's nice-to-have? Let me show you what made the cut..."

**Timing**: 2 minutes

---

## Slide 7: Scope & Focus

### Content

**Title**: Scope & Focus
**Visual**: Simple table showing kept vs dropped:

| **Kept** | **Dropped** |
|----------|-------------|
| ✅ Voice interaction (STT) | ❌ Webcam vision (Slide 6) |
| ✅ Sentiment display | ❌ On-device image conversion (Slide 6) |
| ✅ Simple mood faces | ❌ Complex text rendering |
| ✅ On-device ML | ❌ Spec-driven workflow (Slide 5) |
| ✅ Audio pipeline | |

**Text**:

- Core experience: Talk → React → Respond
- Drop non-essentials ruthlessly
- Focus on what ships

### Speaker Notes

**Brief and direct** (60s total):
> "Between the ambitious vision and reality, I had to make choices. What's core? What's nice-to-have?
>
> Voice interaction - core. Sentiment display - core. Simple mood faces - core.
>
> Webcam vision for drawings? Nice-to-have, dropped. On-device image conversion? Too complex, dropped. Complex text rendering on E-Ink? Not worth it, dropped.
>
> The pattern: Talk, React, Respond. That's MoodBot. Everything else was noise."

### Key Points

- Ruthless scope trimming
- Core experience defined early
- Dropped features already covered in Slides 5-6

### Transition to Slide 7.5
>
> "So what did that core experience need? Audio. I started simple..."

**Timing**: 90 seconds

---

## Slide 7.5: Audio - Simple Wins

### Content

**Title**: Audio: Simple Wins
**Visual**:

- Code snippet: Simple aplay command
- Screenshot: Bumblebee issue #209 on GitHub
- Terminal output: aplay/amixer working

**Text**:

**TTS First:**
- Looked at Bumblebee for on-device TTS
- Found issue #209 immediately - "No TTS support yet"
- **Quick win**: Azure Speech API

**Audio Output:**
- Tried aplay + amixer shell commands
- "It just worked!" (reference LEARNINGS.md:535-546)
- No complex frameworks needed yet

**Proving Feasibility:**
- Can make sound? ✅
- Can speak German? ✅
- Baby step complete

### Speaker Notes

**Opening** (10s):
> "Audio. I started with TTS - text to speech."

**TTS Discovery** (20s):
> "Looked at Bumblebee for on-device TTS. Found the issue immediately - #209, no TTS support yet. Fine. Azure Speech API for a quick win. Proves feasibility, worry about on-device later."

**Audio Output** (30s):
> "Then audio output. I was expecting to need Membrane, complex pipelines... tried aplay and amixer first. Just simple shell commands." *[Reference LEARNINGS.md where you tested this]* "It worked. Can make sound? Check. Can speak German? Check. Baby step complete."

**Transition** (10s):
> "Audio worked. Now to make it smart..."

### Key Points

- Start simple (shell commands before frameworks)
- Pragmatic trade-offs (Azure TTS for quick win)
- Prove feasibility early
- Baby steps visible (audio before AI)

### Transition to Slide 7.6
>
> "Audio worked. Now to make it smart..."

**Timing**: 90 seconds

---

## Slide 7.6: AI Assembly & The Button

### Content

**Title**: AI Assembly & The Button
**Visual**:

- Pipeline architecture diagram showing Button → STT → Sentiment → Display → LLM → TTS
- Photo: Arduino test circuit with your son (button + LED)
- Code snippet: Binary pattern matching for audio
- Diagram: Process supervision (optional)

**Text**:

**On-Device AI Components:**
- LLM inference: SmolLM2 (135M-1.7B params)
- Audio input: Whisper pipeline (Membrane)
- Sentiment: German-Emotions model
- Three models running concurrently on a Raspberry Pi

**But How to Trigger It?**
- Mic doesn't record all the time
- Need a simple trigger
- **Button!**

**Father-Son Electronics Learning:**
- Built Arduino test circuit together
- Simple: Button → LED
- Teaching electronics fundamentals
- Testing debouncing and interrupts

**GPIO Button on Pi:**
- Implemented on actual hardware
- Debounced interrupt handling
- Starts/stops audio pipeline

**Complete Pipeline Architecture:**
- Button → STT → Sentiment → Display → LLM → TTS → Audio

**Elixir Makes It Elegant:**
- Binary pattern matching for audio: `for <<sample::signed-little-16 <- audio>>, do: sample / 32768.0`
- Process isolation: Each model supervised, independent crashes
- Concurrent orchestration: All running simultaneously, no threading

### Speaker Notes

**Opening** (15s):
> "Audio worked. Now for AI. I had three models I wanted to run: Whisper for speech recognition, German-Emotions for sentiment, and SmolLM2 for responses. Three large models, concurrently, on a Raspberry Pi."

**The Button Question** (20s):
> "But how do you trigger it? The mic can't record all the time. Simple: a button. Press once to start recording, press again to stop. Or 60-second timeout."

**Father-Son Moment** (30s):
> "This became a perfect teaching moment with my son. We built an Arduino test circuit together - button to LED. He's learning electronics. I'm testing debouncing and interrupt handling. Then I implemented the GPIO button on the Pi."

**Architecture Emerges** (30s):
> "And here's where the complete pipeline emerged: Button press starts recording. Whisper transcribes. Sentiment analysis determines mood. E-Ink shows the mood. SmolLM2 generates a child-friendly response. Azure TTS speaks it back."

**Elixir Elegance** (40s):
> "Audio processing in Elixir looks like this:" *[Show binary pattern matching code]* "One line. Binary pattern matching - embedded work feeling natural.
>
> But here's the key: **each model is its own supervised process**. Whisper crashes? Only Whisper restarts. Sentiment keeps analyzing. LLM keeps generating. Display keeps updating. **This is why I chose Elixir** - fault isolation for AI workloads.
>
> And all these workloads running concurrently - audio recording while Whisper is doing heavy inference, while the LLM is generating, while the display is updating. No threading complexity. No mutex debugging. BEAM's preemptive scheduler just handles it."

### Key Points

- Arduino circuit: Father-son teaching moment
- Button trigger: Simple solution to complex problem
- Complete pipeline: All pieces come together
- Binary pattern matching: Elixir's embedded strength
- Process isolation: Unique BEAM capability for AI
- Concurrent orchestration: Preemptive scheduling advantage

### Transition to Slide 8
>
> "That's the architecture. But does it actually work? Let me show you..."

**Timing**: 2-3 minutes

---

## Slide 8: Magical Moments - It Works

### Content

**Title**: Magical Moments: It Works!
**Visual**: **VIDEO - Son interacting with MoodBot**

**Video structure** (30-45 seconds):

1. Son presses button
2. Asks question in German
3. Display shows sentiment/mood
4. MoodBot responds with audio
5. Son's reaction

**Optional text overlays during video**:

- 🎤 STT: Whisper
- 🎭 Sentiment Analysis
- 😊 Mood: Happy
- 🤖 LLM: Generating
- 🗣️ TTS: Speaking

### Speaker Notes

**Before video**:
> "Let me show you the complete pipeline in action. My son asks MoodBot a question in German..."

**During video** (light narration or silent - see demo-script.md):

- Option: Let it play naturally for first 10s
- Then add light narration: "Sentiment detected... mood displayed... response generated..."

**After video**:
> "This is what the ecosystem enables - **on-device AI** for understanding and thinking, cloud TTS for quality, all orchestrated by Elixir."

**Mention tech specifically**:

- Membrane made audio pipeline feel like magic
- Bumblebee serving protects from inference crashes
- Nerves handles deployment and OTA updates

### Key Points

- **This is the emotional peak of the talk**
- Working system proves the ecosystem is ready
- Father-son moment resonates emotionally

### Transition to Act III
>
> "After months of small wins, debugging sessions, and dropped features, MoodBot came alive. [Pause] Here's what I'd tell my past self... and what I hope you'll take away."

**Timing**: 60-90 seconds (including 30-45s video)

---

# Act III: Reflection

## Slide 9: Lessons Learned

### Content

**Title**: Lessons Learned
**Visual**: Simple bullet list (cleaner, less crowded)

**Lessons** (Big Picture Only):

**1. Lean on mature libraries**
- Membrane: Audio pipeline abstracted
- Bumblebee: ML serving protects from crashes
- VintageNet: Networking handled
- **Concurrent orchestration just works** - audio, Whisper, LLM, display all simultaneous, no threading complexity
- Don't reinvent solved problems

**2. "Automate the right things, keep thinking about the rest"**
- Claude for boilerplate ✅
- Review what you don't understand ✅
- Back out what you can't explain ✅
- Balance AI assistance with understanding

**3. Ecosystem maturity matters**
- Elixir can do embedded + AI now
- Process isolation, binary pattern matching, preemptive scheduling
- Right tool for the job

### Speaker Notes

**Brief and focused** (90-120s total):

**On ecosystem** (40s):
> "Three big lessons. First: lean on mature libraries. Membrane made audio pipelines simple. Bumblebee made ML serving reliable. VintageNet handled networking. And concurrent orchestration? It just works. All these workloads running simultaneously - no threading, no mutexes. BEAM's scheduler handles it."

**On vibe coding** (30s):
> "Second: 'Automate the right things, keep thinking about the rest.' I used Claude for GenServer boilerplate. But reviewed everything I didn't understand. When Claude generated code I couldn't explain? I backed it out. Balance AI assistance with understanding."

**On Elixir's readiness** (30s):
> "Third: The ecosystem is mature now. Elixir can do embedded plus AI. Process isolation for fault-tolerant ML. Binary pattern matching for audio. Concurrent orchestration without complexity. The right tool for this job."

### Key Points

- Lessons already woven into Slides 5-6 (baby steps, vibe coding reality, pragmatism)
- This slide focuses on **big-picture takeaways**
- Ecosystem maturity message (sets up Slide 10 frontiers)

### Transition to Slide 10
>
> "The ecosystem got me this far. But there's still frontier ahead - places where *you* can help shape the future..."

**Timing**: 2 minutes (trimmed from 2-3 minutes)

---

## Slide 10: Frontiers to Explore

### Content

**Title**: Frontiers to Explore
**Visual**: Icons or diagrams for each frontier

**Opportunities**:

**1. On-device TTS in Bumblebee** ⭐

- Currently using Azure Speech API (cloud dependency)
- Bumblebee TTS requested: GitHub issue #209
- Would complete fully on-device AI experience

**2. Broader model support**

- Gemma, DeepSeek, and more
- Bumblebee can expand model coverage
- Community contributions welcome

**3. Faster on-device inference**

- Optimization, quantization
- vLLM-style inference engines
- Gap between "toy" and "useful tool"

**4. AI acceleration hardware**

- HAILO HAT and similar accelerators
- Driver and runtime support needed
- Could dramatically improve inference speed

**5. Smoother cross-compilation**

- Better toolchains for ARM targets
- Blueprints and standardized workflows
- Lower barrier to entry

### Speaker Notes

**Opening**:
> "The ecosystem got me this far. But there's still work to do - and *you* can help."

**Emphasize TTS** (your current pain point):
> "I'm using Azure's cloud API for TTS because Bumblebee doesn't support it yet. This means MoodBot needs internet. Completing the on-device experience is a key frontier."

**Invitational tone**:
> "These aren't complaints - they're opportunities. The foundation is strong. Now we can push the boundaries together."

### Key Points

- Positive framing: opportunities, not problems
- Community can contribute
- Ecosystem is strong enough to build on

### Transition to Slide 11
>
> "But here's the thing - you don't need everything perfect to start. [Build energy] The ecosystem is ready *now*."

**Timing**: 90-120 seconds

---

## Slide 11: Takeaway - Ecosystem is Ready

### Content

**Title**: The Ecosystem is Ready
**Visual**:

- Large quote or key message centered
- Background: Subtle MoodBot image or video callback

**Main Message**:
> "Elixir's ecosystem has quietly grown powerful enough to bring AI and hardware together.
>
> You can build real robots now — starting on your laptop, deploying to a Pi, without leaving Elixir."

**Starter Steps** (sidebar or bottom):

- Pick a Raspberry Pi (3, 4, or 5)
- Try Membrane for audio processing
- Use Bumblebee for ML model serving
- Adopt MockHAL pattern for development
- Build something small, iterate

**Brief mentions**:

- Nerves for embedded deployment
- VintageNet for networking
- OTA updates out of the box

### Speaker Notes

**Deliver core message with conviction**:
> "Elixir's ecosystem has quietly grown powerful enough to bring AI and hardware together. You can build real robots now - starting on your laptop, deploying to a Pi, without leaving Elixir."

**Actionable closing**:
> "Pick a Raspberry Pi. Choose Membrane for audio. Try Bumblebee for ML. Use the MockHAL pattern for development. Build something small. Iterate."

**Video callback** (10-15s highlight from Slide 8):

- Show brief clip of son interacting with MoodBot
- Let emotion land

**Final line**:
> "And maybe, like me, you'll answer your kid's question: 'Can we have a robot?' Yes. Yes, we can build one."

### Key Points

- Inspirational close
- Actionable (not just motivational)
- Emotional callback reinforces message

### Transition to Slide 12
>
> "Thank you. I'm happy to take your questions."

**Timing**: 90-120 seconds (including video callback)

---

## Slide 12: Thank You / Q&A

### Content

**Title**: Thank You
**Visual**:

- MoodBot photo (assembled, looking friendly)
- Your contact info:
  - GitHub: [your-username]
  - Twitter/X: [your-handle]
  - Email: [your-email]

**Text**:

- Questions?
- Code: github.com/[your-repo]
- Slides: [URL to slides]

### Speaker Notes

- Warm, open, approachable
- Invite questions
- Be prepared for technical deep-dives

**Likely questions to prepare for**:

- How long did it take to build?
- What's the cost of components?
- Can you run bigger models on RPi5?
- How's the latency of the pipeline?
- Would you use this approach for production?

**Timing**: Remaining time for Q&A

---

# Summary & Timing Breakdown

| Slide | Title | Duration | Act |
|-------|-------|----------|-----|
| 1 | Title | 30s | Intro |
| 2 | The Spark | 90-100s | Act I |
| 3 | The Gap | 60s | Act I |
| 4 | Tools | 90s | Act I |
| **5** | **E-Ink: Visual First** | **2-3 min** | **Act II** |
| **6** | **Image Pipeline** | **2 min** | **Act II** |
| **7** | **Scope & Focus** | **90s** | **Act II** |
| **7.5** | **Audio Wins** | **90s** | **Act II** |
| **7.6** | **AI Assembly + Button** | **2-3 min** | **Act II** |
| 8 | Demo | 90s | Act II |
| **9** | **Lessons (trimmed)** | **2 min** | **Act III** |
| 10 | Frontiers | 2 min | Act III |
| 11 | Takeaway | 2 min | Act III |
| 12 | Q&A | Variable | Closing |

**Total**: ~19-20 minutes + Q&A (13 slides)
**Buffer**: 2-3 minutes for audience reactions

**Structural Changes**:
- Slide 5: Now E-Ink journey (was generic "First Wins")
- Slide 6: Now Image Pipeline (was "Major Obstacles")
- Slide 7: Trimmed to 90s (lessons distributed)
- Slide 7.5: NEW - Audio Wins (baby step)
- Slide 7.6: NEW - AI Assembly + Button (with Arduino circuit + Elixir gems)
- Slide 9: Trimmed to 2min (big-picture lessons only)

---

# Quick Reference

## Videos

- **Slide 5**: E-Ink first render (5-8s) - at end after describing bug discovery
- **Slide 7.6**: Arduino circuit photo with son (static image, not video)
- **Slide 8**: MoodBot interaction (30-45s) - **CRITICAL**
- **Slide 11**: Callback highlight (10-15s) - recommended

## Key Emotional Beats

1. **Connection**: Son's request (Slide 2)
2. **Discovery**: Tools exist (Slide 4)
3. **Ambition**: Webcam MCP vision (Slide 5)
4. **Struggle**: 5am E-Ink debugging (Slide 5)
5. **Pragmatism**: On-device image pipeline → host preprocessing (Slide 6)
6. **Baby steps**: Audio wins (Slide 7.5)
7. **Father-son**: Arduino circuit learning (Slide 7.6)
8. **Pride**: Working system (Slide 8)
9. **Invitation**: You can do this (Slide 11)

## Vibe Coding Thread

- Slide 3: AI assistants gave confidence
- Slide 5: hexdocs MCP + SSH MCP excitement → webcam MCP ambition
- Slide 5: Spec-driven frenzy → baby steps
- Slide 5: Claude wrote it, I debugged it (5am)
- Slide 9: Automate right things, keep thinking about rest
- Slide 11: Ecosystem enables, you still iterate

## Elixir Gems Thread

- Slide 7.6: Binary pattern matching for audio
- Slide 7.6: Process isolation for AI workloads
- Slide 7.6: Concurrent orchestration (preemptive scheduling)
- Slide 9: Mentioned as ecosystem maturity

## Core Takeaway (Repeat 3x)

1. **Slide 4 setup**: "Tools changed everything"
2. **Slide 7.5 proof**: "Ecosystem orchestrates complex pipeline"
3. **Slide 11 close**: "Ecosystem is ready NOW - you can build real robots"

---

# Pre-Talk Checklist

## Content

- [ ] All slides finalized
- [ ] Videos exported and tested
- [ ] Speaker notes reviewed
- [ ] Timing practiced (aim for 18-19 min to allow buffer)
- [ ] Transitions memorized

## Technical

- [ ] Slides on laptop + backup USB
- [ ] Videos playback tested
- [ ] Fonts embedded (if using custom fonts)
- [ ] Clicker/remote tested
- [ ] Backup plan for video playback failures

## Practice

- [ ] Full run-through 2-3 times
- [ ] Timing adjusted
- [ ] Transitions smooth
- [ ] Q&A prep (common questions)
- [ ] Energy pacing feels right

**You've got this! 🚀**
