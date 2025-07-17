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

When debugging issues on Nerves devices, use SSH MCP with direct Elixir evaluation instead of interactive IEx sessions.

**Setup:** Configure ssh-mcp (https://github.com/tufantunc/ssh-mcp) to connect to the Nerves device.

**Pattern:** Use `ssh nerves.local "iex -e 'command' --no-halt"` for non-interactive debugging.

### Standard Debugging Commands

**Network Overview:**
```bash
ssh nerves.local "iex -e 'VintageNet.info' --no-halt"
```

**WiFi Debugging:**
```bash
# WiFi interface status
ssh nerves.local "iex -e 'VintageNet.get(\"interface.wlan0.state\") |> IO.inspect' --no-halt"

# WiFi configuration  
ssh nerves.local "iex -e 'VintageNet.get_configuration(\"wlan0\") |> IO.inspect' --no-halt"

# Available networks
ssh nerves.local "iex -e 'VintageNet.scan(\"wlan0\") |> IO.inspect' --no-halt"

# All interfaces
ssh nerves.local "iex -e 'VintageNet.all_interfaces() |> IO.inspect' --no-halt"
```

**Error-Safe Debugging:**
```bash
ssh nerves.local "iex -e 'try do; VintageNet.get_configuration(\"wlan0\") |> IO.inspect; rescue e -> IO.inspect({:error, e}); end' --no-halt"
```

### Key Principles

1. **Always use `--no-halt`** to prevent interactive IEx sessions
2. **Wrap risky commands in try/rescue** blocks for robust error handling  
3. **Use `IO.inspect`** for complex data structures
4. **Test commands manually first** before SSH MCP automation
5. **Chain related commands** in single execution when possible

This approach enables automated debugging through Claude Code without manual intervention.

## Development Workflow

- At the end of a feature, compile a brief yet complete git commit message. Use contentional commits with the most suitable tag. Ask if you should do the git commit.
