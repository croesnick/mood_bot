# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MoodBot is an Elixir/Nerves project for building a hardware robot that runs on embedded devices like Raspberry Pi. It's designed as a learning project for exploring hardware programming, with features like text-to-speech, e-ink display mood indicators, and AI-powered behavior.

## Architecture

This is a standard Nerves application with the following structure:

- **Main application**: `MoodBot.Application` - OTP supervisor that manages child processes
- **Target-specific compilation**: Supports multiple embedded targets (RPi variants, BeagleBone, etc.)
- **Configuration**: Environment-specific configs in `config/` with host vs target separation
- **Firmware**: Uses Nerves framework for embedded deployment with `rootfs_overlay/`

The application uses a target-conditional architecture where different child processes run based on whether it's running on `:host` (development) or embedded targets.

## Development Instructions

- Use the `hexdocs` mcp server to look up Elixir library documentation
- Run `mix format` after finishing a feature to ensure consistent code formatting
- Run `mix credo --strict` and `mix dialyzer` and ensure all findings are dealt with
- Always check if the usage documented in the README needs to be adjusted
- For diagrams, try to use mermaid whenever possible. Ensure the diagrams are simple, to the point, easy to understand, and properly labeled.

## Development Commands

### Core Development

```bash
# Install dependencies
mix deps.get

# Run on host for development
mix run

# Run tests
mix test

# Interactive shell
iex -S mix
```

### Firmware/Embedded Development

```bash
# Set target (e.g., rpi4, rpi5, etc.)
export MIX_TARGET=rpi4

# Build firmware
mix firmware

# Burn to SD card
mix burn

# Upload to running device
mix upload
```

### Available Targets

The project supports multiple embedded targets: `:rpi0`, `:rpi3`, `:rpi3a`, `:rpi4`, `:rpi5`, `:x86_64`.

## Key Dependencies

- **Nerves**: Embedded systems framework
- **nerves_pack**: Common networking and utilities for Nerves
- **ring_logger**: Circular buffer logging for embedded systems
- **toolshed**: Debugging utilities for Nerves
- **shoehorn**: Application bootstrap for embedded systems

## Development Notes

- Use `config/host.exs` for host-specific development configuration
- Use `config/target.exs` for embedded target configuration
- The preferred CLI target for `run` and `test` is `:host`
- Firmware includes custom rootfs overlay from `rootfs_overlay/`

## Nerves Device Debugging

### SSH MCP Remote Debugging

When debugging issues on Nerves devices, use SSH MCP with direct Elixir function calls instead of interactive IEx sessions.

**Setup:** Configure ssh-mcp (https://github.com/tufantunc/ssh-mcp) to connect to the Nerves device.

**Pattern:** Use direct function calls without `iex -e` wrapper for simple, reliable debugging.

### Standard Debugging Commands

**Network Overview:**
```bash
VintageNet.info()
```

**WiFi Debugging:**
```bash
# WiFi interface status
VintageNet.get("interface.wlan0.state")

# WiFi configuration  
VintageNet.get_configuration("wlan0")

# Available networks
VintageNet.scan("wlan0")

# All interfaces
VintageNet.all_interfaces()
```

**MoodBot Status (when application is running):**
```bash
MoodBot.WiFiConfig.status()
```

**System Information:**
```bash
:os.type()
System.version()
Application.started_applications() |> Enum.map(fn {name, _desc, _vsn} -> name end)
```

### Key Principles

1. **Use direct function calls** instead of `iex -e` wrappers
2. **Functions return data directly** - no need for `IO.inspect`
3. **Keep commands simple** and focused on single operations
4. **Use VintageNet functions** for network debugging (always available)
5. **Test commands manually first** before SSH MCP automation

This approach enables automated debugging through Claude Code without manual intervention.

## Development Workflow

- At the end of a feature, compile a brief yet complete git commit message. Use contentional commits with the most suitable tag. Ask if you should do the git commit.

## Architecture & Design Principles

### Research-Driven Decision Making
- **Always research before refactoring**: The "obvious" solution isn't always the best one
- **Documentation as source of truth**: When code and docs diverge, docs often represent intended behavior
- **Validate assumptions**: Question initial assumptions through systematic investigation

### Tool Selection Philosophy
- **Right tool for the job**: Choose tools based on actual requirements, not perceived complexity
- **GenServer for simple state machines**: Prefer GenServer over formal state machine libraries for simple state tracking
- **Incremental improvement over rewrites**: Sometimes polishing existing code is better than starting over

### State Machine Design Patterns
- **Manual state tracking is acceptable**: For simple state machines in GenServer, manual state tracking with validation is appropriate
- **Centralized state transitions**: Extract state transition logic into dedicated functions
- **Validation before action**: Always validate state before performing operations
- **Pattern matching for clarity**: Use guards and pattern matching to make intent explicit

### When NOT to Use Formal State Machine Libraries
- **gen_statem**: Overkill for simple state tracking; designed for complex protocols/persistent connections
- **Machinery**: For data state machines (user workflows), not process state machines
- **Finitomata**: For complex FSMs needing visual documentation

### Code Quality Principles
- **Extract common patterns**: Consolidate repetitive logic into reusable functions
- **Comprehensive error handling**: Return consistent error tuples and handle gracefully
- **Detailed logging**: Include context and state information in log messages
- **Validation functions**: Separate validation logic from business logic

### Development Target Memories
- Use `MIX_TARGET=rpi3` for Raspberry Pi 3 specific development and firmware builds