# MoodBot 🤖

Ever had your kid ask for a robot — and thought, "Hey… maybe we could build one together"?

MoodBot is the result of that idea: a little robot built with Elixir, Nerves, a Raspberry Pi, and some help from AI. It talks using text-to-speech, shows its mood on an e-ink display, and grows over time — from basic GenServers to more playful, AI-powered behavior.

It's not just about the end result — it's also about exploring hardware, learning by doing, and seeing how far curiosity (and a few good tools) can take you.

## Quick Start (Development Mode)

**Get started immediately without any hardware!** MoodBot includes a mock HAL that simulates the e-ink display for development.

### Prerequisites

- Elixir 1.18+ and Erlang/OTP 25+
- Mix build tool

### 1. Clone and Setup

```bash
git clone <repository-url>
cd mood_bot
mix deps.get
```

### 2. Run in Development Mode

```bash
# Start the application with mock hardware
mix run --no-halt

# Or start an interactive shell
iex -S mix
```

The application automatically uses the MockHAL when running on `:host` (your development machine), which logs all display operations to the console instead of sending them to actual hardware.

### 3. Try the Display API

In the IEx shell, you can interact with the mock display:

```elixir
# Initialize the display
MoodBot.Display.init_display()

# Clear the display (logs to console)
MoodBot.Display.clear()

# Show different moods
MoodBot.Display.show_mood(:happy)
MoodBot.Display.show_mood(:sad)
MoodBot.Display.show_mood(:neutral)
MoodBot.Display.show_mood(:angry)
MoodBot.Display.show_mood(:surprised)

# Check display status
MoodBot.Display.status()

# Display raw image data (generates test pattern)
alias MoodBot.DisplayTestHelper
test_image = DisplayTestHelper.test_image_data()
MoodBot.Display.display_image(test_image)

# Put display to sleep
MoodBot.Display.sleep()
```

## Development Workflow

### Running Tests

```bash
# Run all tests
mix test

# Run tests with coverage
mix test --cover

# Run specific test files
mix test test/mood_bot/display_test.exs
```

### Code Quality

```bash
# Format code
mix format

# Check code quality
mix credo --strict

# Run static analysis
mix dialyzer
```

### Understanding the Mock HAL

The MockHAL (`MoodBot.Display.MockHAL`) simulates all hardware operations:

- **SPI writes**: Logged with data size and first 8 bytes
- **GPIO operations**: Logs pin state changes with descriptions
- **Busy pin**: Randomly simulates busy/ready states
- **Sleep**: Actually sleeps to simulate timing

Example mock output:

```plaintext
[info] MockHAL: Initializing MockHAL for development mode
[info] MockHAL: SPI write 5 bytes: <<1, 2, 3, 4, 5>>
[info] MockHAL: Set DC pin to 1 (data mode)
[info] MockHAL: Set RST pin to 0 (active)
[info] MockHAL: Read BUSY pin: 0 (ready)
```

## Architecture Overview

MoodBot uses a layered architecture for hardware abstraction:

```plaintext
┌──────────────────────────────┐
│     MoodBot.Display          │  ← High-level API
│        (GenServer)           │
├──────────────────────────────┤
│   MoodBot.Display.Driver     │  ← E-ink display protocol
├──────────────────────────────┤
│      HAL Interface           │  ← Hardware abstraction
│  ┌──────────────┬───────────┐│
│  │   MockHAL    │  RpiHAL   ││  ← Platform implementations
│  │ (Development)│(Hardware) ││
│  └──────────────┴───────────┘│
└──────────────────────────────┘
```

### Key Components

- **MoodBot.Display**: Main GenServer providing the public API
- **MoodBot.Display.Driver**: E-ink display communication protocol
- **MoodBot.Display.HAL**: Behavior defining hardware interface
- **MoodBot.Display.MockHAL**: Development implementation (no hardware)
- **MoodBot.Display.RpiHAL**: Raspberry Pi hardware implementation

## API Reference

### Display Control

```elixir
# Initialize hardware
{:ok | :error, reason} = MoodBot.Display.init_display()

# Clear display to white
:ok = MoodBot.Display.clear()

# Display moods (:happy, :sad, :neutral, :angry, :surprised)
:ok = MoodBot.Display.show_mood(:happy)

# Display raw image data (binary, 1 bit per pixel)
:ok = MoodBot.Display.display_image(image_binary)

# Sleep mode
:ok = MoodBot.Display.sleep()

# Get status
%{initialized: boolean(), display_state: atom(), ...} = MoodBot.Display.status()
```

### Image Format

The display expects binary data where:

- 1 bit per pixel (0 = black, 1 = white)
- Size: `(width / 8) * height` bytes
- Default dimensions: 296x128 pixels = 4736 bytes

## Hardware Setup (For Actual Deployment)

### Supported Hardware

- Raspberry Pi (Zero, 3, 3A+, 4, 5)
- Waveshare 2.9" e-ink display
- MicroSD card (8GB+)

### Pin Connections

| Display Pin | RPi GPIO | Purpose |
|-------------|----------|---------|
| VCC         | 3.3V     | Power   |
| GND         | GND      | Ground  |
| DIN         | SPI MOSI | Data    |
| CLK         | SPI SCLK | Clock   |
| CS          | GPIO 8   | Chip Select |
| DC          | GPIO 25  | Data/Command |
| RST         | GPIO 17  | Reset   |
| BUSY        | GPIO 24  | Busy Signal |

### Building for Hardware

```bash
# Set target (rpi4, rpi5, etc.)
export MIX_TARGET=rpi4

# Build firmware
mix firmware

# Burn to SD card (replace /dev/sdX with your card)
mix burn

# Upload to running device over network
mix upload
```

## Configuration

### Application Config

```elixir
# config/target.exs (hardware-specific)
config :mood_bot, MoodBot.Display,
  spi_device: "spidev0.0",
  dc_pin: 25,
  rst_pin: 17,
  busy_pin: 24,
  cs_pin: 8

# config/host.exs (development)
# Uses MockHAL automatically, no config needed
```

### Runtime Configuration

Override config when starting the display:

```elixir
custom_config = %{dc_pin: 26, rst_pin: 18}
{:ok, pid} = MoodBot.Display.start_link(config: custom_config, name: :my_display)
```

## Troubleshooting

### Common Issues

**Display not initializing:**

- Check pin connections and power supply
- Verify SPI is enabled: `sudo raspi-config` → Interface Options → SPI

**Build failures:**

- Ensure correct MIX_TARGET is set
- Clean build: `mix deps.clean --all && mix deps.get`

**Mock HAL not working:**

- Ensure running on `:host` target (not hardware target)
- Check logs for MockHAL initialization messages

### Debug Mode

Enable detailed logging:

```elixir
# In IEx
Logger.configure(level: :debug)

# Or in config
config :logger, level: :debug
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Make changes and add tests
4. Run code quality checks: `mix format && mix credo --strict && mix dialyzer`
5. Submit a pull request

## License

[Add your license here]

## Learn More

- [Nerves Project](https://nerves-project.org/) - Embedded Elixir framework
- [Circuits](https://github.com/elixir-circuits) - Hardware interface libraries
- [E-ink Display Datasheet](https://www.waveshare.com/wiki/2.9inch_e-Paper_Module) - Hardware specifications
