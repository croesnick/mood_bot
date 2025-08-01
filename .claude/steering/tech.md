# Technical Standards: MoodBot

## Technology Stack

### Core Framework

- **Elixir/OTP**: Primary programming language for robust, concurrent embedded applications
- **Nerves**: Embedded systems framework for building firmware and managing deployments
- **Circuits Libraries**: Hardware interface libraries (circuits_gpio, circuits_spi)

### Hardware Platform

- **Target Devices**: Raspberry Pi (Zero, 3, 3A+, 4, 5)
- **Primary Display**: Waveshare 2.9" e-ink display (296x128 pixels, 3-color: black/white/red)
- **Communication Protocols**: SPI for display, GPIO for control signals
- **Networking**: WiFi via VintageNet, optional Ethernet

### AI/ML Stack

- **Preferred Approach**: On-device processing using Nerves-compatible ML libraries
- **Primary Libraries**: Axon, Bumblebee for neural network deployment
- **Fallback Strategy**: Remote AI services when hardware limitations require
- **Target Use Cases**: Computer vision, mood detection, speech processing

### Development Dependencies

- **Code Quality**: Credo (linting), Dialyzer (static analysis), ExUnit (testing)
- **Development Tools**: Ring Logger (embedded logging), Toolshed (debugging)
- **Environment Management**: Target-conditional compilation, asdf for version management

## Architecture Patterns

### Hardware Abstraction Layer (HAL)

```
Application Layer
    ↓
GenServer (Business Logic)
    ↓
Driver (Protocol/Timing)
    ↓
HAL Interface
    ↓
MockHAL (Development) | RpiHAL (Hardware)
```

**Principles:**

- Clean separation between business logic and hardware specifics
- MockHAL enables laptop development without physical hardware
- Driver layer handles device-specific protocols and timing
- HAL interface provides consistent API regardless of target

### OTP Supervision Tree

- Use standard OTP patterns for robust, fault-tolerant systems
- GenServers for stateful hardware interfaces
- Supervisors for automatic recovery from hardware failures
- Target-conditional child processes (host vs embedded targets)

### State Management Patterns

- **Simple State Machines**: Use GenServer with manual state tracking for simple cases
- **Validation Before Action**: Always validate state before hardware operations
- **Centralized Transitions**: Extract state transition logic into dedicated functions
- **Pattern Matching**: Use guards and pattern matching for clarity

**When NOT to use formal state machine libraries:**

- gen_statem: Overkill for simple state tracking
- Complex FSM libraries: Unless visual documentation is required

## Testing Strategy

### Hybrid Hardware Testing Approach

#### Development Testing (No Hardware Required)

- **MockHAL**: Simulates all hardware operations with detailed logging
- **Bitmap Output**: Display operations saved as viewable PBM images
- **Unit Tests**: Comprehensive coverage of business logic and protocols
- **Integration Tests**: Full application flows using mocked hardware

#### Hardware Integration Testing

- **Camera-based Validation**: Automated photography of actual display output
- **Fuzzy Image Comparison**: Compare camera captures to expected display images
- **Real Device Testing**: Critical path verification on actual hardware
- **GPIO Validation**: Verify pin states and signal timing

#### Test Organization

```
test/
├── unit/              # Pure business logic tests
├── integration/       # MockHAL-based integration tests
├── hardware/          # Real hardware tests (optional)
└── support/           # Test helpers and utilities
```

## Code Quality Standards

### Formatting and Style

- **Required**: `mix format` before committing any changes
- **Linting**: `mix credo --strict` must pass without warnings
- **Static Analysis**: `mix dialyzer` findings must be addressed
- **Documentation**: Comprehensive module and function documentation

### Error Handling Patterns

- **Consistent Error Tuples**: Return `{:ok, result}` or `{:error, reason}`
- **Graceful Degradation**: Handle hardware failures without application crash
- **Detailed Logging**: Include context and state in error messages
- **Validation Functions**: Separate input validation from business logic

### Common Patterns to Extract

- Consolidate repetitive hardware operation patterns
- Create reusable validation functions
- Extract common error handling into utilities
- Build helpers for testing hardware interactions

## Development Workflow

### Environment Setup

- **Target Management**: Use `MIX_TARGET` environment variable for builds
- **Version Compatibility**: Maintain Erlang/Elixir version compatibility with Nerves systems
- **Configuration Split**: host.exs for development, target.exs for embedded deployment

### Development Commands

```bash
# Development
mix deps.get && mix run --no-halt    # Host development
iex -S mix                          # Interactive development

# Quality Checks
mix format                          # Code formatting
mix credo --strict                  # Code quality
mix dialyzer                        # Static analysis
mix test                           # Test suite

# Hardware Deployment
MIX_TARGET=rpi4 mix firmware       # Build firmware
MIX_TARGET=rpi4 mix burn           # Flash to SD card
MIX_TARGET=rpi4 mix upload         # OTA update
```

### Debugging Approach

- **SSH MCP**: Use direct function calls for remote debugging
- **VintageNet Functions**: Standard network debugging commands
- **GPIO Debugging**: Built-in helpers for hardware troubleshooting
- **MockHAL Logging**: Detailed simulation output for development

## Integration Guidelines

### Adding New Hardware Components

1. **Define HAL Interface**: Create consistent API for the component
2. **Implement MockHAL**: Enable development without hardware
3. **Build Driver Layer**: Handle device-specific protocols
4. **Create GenServer**: Manage state and provide application API
5. **Add Tests**: Unit tests for logic, integration tests with MockHAL
6. **Document Usage**: Include examples and troubleshooting guides

### AI Model Integration

1. **Evaluate On-Device Capability**: Test model performance on target hardware
2. **Implement Fallback Strategy**: Design graceful degradation to remote services
3. **Optimize for Constraints**: Consider memory, CPU, and power limitations
4. **Measure Performance**: Benchmark inference time and resource usage
5. **Document Trade-offs**: Clearly explain on-device vs remote decisions

## Performance Considerations

### Hardware Constraints

- **Memory Management**: Be mindful of Raspberry Pi' limited RAM
- **CPU Usage**: Consider impact of AI inference on system responsiveness
- **Power Consumption**: Design for battery operation when possible
- **Storage**: Firmware size impacts deployment and update times

### Network Usage

- **Bandwidth Efficiency**: Minimize remote service calls
- **Offline Operation**: Core functionality should work without internet
- **Update Strategy**: Use delta updates for bandwidth-limited deployments

## Security Best Practices

### Secrets Management

- **Environment Variables**: Use .env files for development secrets
- **No Hardcoded Credentials**: Never commit WiFi passwords or API keys
- **SSH Key Management**: Proper public key authentication for device access
- **Secure Defaults**: Safe configuration out of the box

### Network Security

- **WiFi Configuration**: Support modern WPA2/WPA3 security
- **SSH Access**: Secure shell access for debugging and updates
- **OTA Updates**: Encrypted firmware updates over network
- **Network Isolation**: Consider device network segmentation
