# Project Structure: MoodBot

## Directory Organization

### Root Structure
```
mood_bot/
├── lib/                    # Source code
├── test/                   # Test suite
├── config/                 # Configuration files
├── priv/                   # Private application files
├── rootfs_overlay/         # Nerves firmware customizations
├── .claude/                # Claude Code workflow and docs
├── planning/               # Architecture and planning documents
├── talks/                  # Presentation materials and assets
└── docs/                   # Generated documentation
```

### Core Application Structure
```
lib/
├── mood_bot.ex                    # Main module and public API
├── mood_bot/
│   ├── application.ex             # OTP Application supervisor
│   ├── iex_helpers.ex            # Interactive debugging helpers
│   ├── network_monitor.ex        # Network status monitoring
│   ├── wifi_config.ex            # WiFi configuration management
│   └── display/                  # Display subsystem
│       ├── display.ex            # Main display GenServer
│       ├── driver.ex             # E-ink display driver
│       ├── hal.ex                # HAL interface definition
│       ├── mock_hal.ex           # Development mock implementation
│       ├── rpi_hal.ex            # Raspberry Pi hardware implementation
│       └── bitmap.ex             # Bitmap utilities and helpers
```

### Configuration Structure
```
config/
├── config.exs              # Common configuration
├── host.exs                # Development (laptop) configuration
└── target.exs              # Embedded device configuration
```

### Test Organization
```
test/
├── mood_bot_test.exs            # Main module tests
├── mood_bot/
│   ├── application_test.exs     # Application startup tests
│   ├── network_monitor_test.exs # Network monitoring tests
│   ├── wifi_config_test.exs     # WiFi configuration tests
│   └── display/                 # Display subsystem tests
│       ├── display_test.exs     # Display GenServer tests
│       ├── driver_test.exs      # Driver protocol tests
│       ├── mock_hal_test.exs    # MockHAL behavior tests
│       └── bitmap_test.exs      # Bitmap utility tests
├── support/                     # Test support files
│   ├── test_helper.exs         # Test configuration
│   └── fixtures/               # Test data and fixtures
└── integration/                 # Integration test suites
    ├── display_integration_test.exs
    └── hardware/               # Hardware-specific tests (optional)
```

## Naming Conventions

### Module Names
- **Namespace**: All modules under `MoodBot.*`
- **GenServers**: Use descriptive names like `MoodBot.Display`, `MoodBot.NetworkMonitor`
- **Protocols/Behaviors**: Interfaces like `MoodBot.Display.HAL`
- **Implementations**: Descriptive suffixes like `MockHAL`, `RpiHAL`
- **Utilities**: Clear purpose like `MoodBot.Images.Bitmap`

### File Names
- **Snake case**: All file names in `snake_case.ex`
- **Match module**: File name should match the module name
- **Descriptive**: Names should clearly indicate the module's purpose
- **Grouped by feature**: Related modules in subdirectories

### Function Names
- **Public API**: Clear, descriptive names for public functions
- **Private helpers**: Prefix with underscore for internal functions
- **GenServer callbacks**: Follow OTP naming conventions
- **Hardware operations**: Use hardware-domain terminology (e.g., `init_display`, `refresh_screen`)

## Component Organization Patterns

### Hardware Abstraction Layer (HAL) Pattern
```
feature/
├── feature.ex              # Public API GenServer
├── driver.ex               # Protocol and timing logic
├── hal.ex                  # HAL behavior definition
├── mock_hal.ex            # Development implementation
├── rpi_hal.ex             # Hardware implementation
└── utilities.ex           # Supporting utilities
```

**Example:** Display subsystem follows this pattern exactly

### Network/Connectivity Pattern
```
connectivity/
├── network_monitor.ex      # Real-time network monitoring
├── wifi_config.ex         # WiFi configuration management
└── connection_helpers.ex  # Shared networking utilities
```

### AI/ML Integration Pattern (Future)
```
ai/
├── ai_coordinator.ex       # Main AI coordination GenServer
├── models/                 # Model management
│   ├── mood_detector.ex    # Mood detection model
│   ├── speech_processor.ex # Speech processing
│   └── model_loader.ex     # Model loading utilities
├── inference/              # Inference engines
│   ├── local_inference.ex  # On-device inference
│   └── remote_inference.ex # Cloud fallback
└── data/                   # Data processing
    ├── image_processor.ex  # Image preprocessing
    └── audio_processor.ex  # Audio preprocessing
```

## File Organization Guidelines

### New Feature Development
1. **Start with main module**: Create the primary GenServer/module
2. **Add supporting modules**: Utilities, helpers in same directory
3. **Implement HAL pattern**: For hardware components, follow HAL structure
4. **Mirror in tests**: Test structure mirrors lib/ structure
5. **Document in README**: Update usage examples and API documentation

### Configuration Files
- **Environment-specific**: Use host.exs vs target.exs pattern
- **Feature toggles**: Group related configuration by feature
- **Secrets**: Use environment variables, never hardcode
- **Documentation**: Comment complex configuration decisions

### Documentation Structure
```
.claude/
├── steering/               # Project steering documents
│   ├── product.md         # Product vision and goals
│   ├── tech.md            # Technical standards
│   └── structure.md       # This file
├── specs/                 # Feature specifications
│   └── feature-name/      # Individual feature specs
│       ├── requirements.md
│       ├── design.md
│       └── tasks.md
└── commands/              # Custom Claude Code commands
    └── spec-*.md          # Workflow commands
```

### Planning and Architecture
```
planning/
├── architecture/          # System architecture documents
├── research/              # Investigation and research notes
├── decisions/             # Architecture decision records (ADRs)
└── diagrams/              # System diagrams and flowcharts
```

## Code Organization Principles

### Separation of Concerns
- **Business Logic**: Separate from hardware specifics
- **Protocol Handling**: Isolate in driver layer
- **State Management**: Centralize in GenServers
- **Configuration**: Externalize from application logic

### Dependency Management
- **Interface Definitions**: Use behaviors for abstraction
- **Dependency Injection**: Pass dependencies to GenServers
- **Target Conditionals**: Use Mix.target() for platform-specific code
- **Feature Flags**: Environment-based feature enabling

### Error Handling Organization
- **Consistent Patterns**: Use similar error handling across modules
- **Error Types**: Define custom error types for different failure modes
- **Recovery Strategies**: Centralize retry and recovery logic
- **Logging Standards**: Consistent log levels and formats

## Testing File Organization

### Test Grouping
- **Unit Tests**: Pure logic, no side effects
- **Integration Tests**: Multiple components working together
- **Hardware Tests**: Real hardware validation (optional)
- **Property Tests**: Use PropCheck for complex data validation

### Test Utilities
```
test/support/
├── test_helper.exs         # Global test configuration
├── fixtures/               # Test data files
│   ├── images/            # Test images for display testing
│   └── configurations/    # Test configuration files
├── mocks/                  # Test doubles and mocks
│   ├── mock_hardware.ex   # Hardware simulation
│   └── mock_network.ex    # Network simulation
└── helpers/                # Test helper functions
    ├── display_helpers.ex  # Display testing utilities
    └── network_helpers.ex  # Network testing utilities
```

## Extension Guidelines

### Adding New Hardware Components
1. **Create subdirectory**: Under appropriate parent (e.g., `lib/mood_bot/sensors/`)
2. **Follow HAL pattern**: Implement behavior, mock, and hardware versions
3. **Add to supervision tree**: Include in application.ex
4. **Mirror test structure**: Create corresponding test files
5. **Update documentation**: Add usage examples and API docs

### AI/ML Feature Integration
1. **Evaluate placement**: Determine if it's core feature or extension
2. **Follow inference pattern**: Local/remote strategy with fallbacks
3. **Consider resource usage**: Memory and CPU impact on other features
4. **Add performance tests**: Benchmark inference times and resource usage
5. **Document trade-offs**: Explain on-device vs cloud decisions

### Configuration Extension
1. **Group by feature**: Related configs in same section
2. **Environment awareness**: Support host vs target differences
3. **Validation**: Add config validation functions
4. **Documentation**: Comment complex or non-obvious settings
5. **Backwards compatibility**: Handle config migrations gracefully