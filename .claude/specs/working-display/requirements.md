# Requirements Document
# Feature: working-display

## Overview

Ensure the E-Ink display interaction cycle works reliably and in line with the Python reference driver implementation from Waveshare. The display subsystem must provide consistent, reliable hardware interaction that matches the documented driver behavior, with proper GPIO pin configuration per DRIVER.md specifications.

## Codebase Analysis Summary

The existing display system follows a well-structured HAL pattern:

**Existing Architecture:**
- **Display GenServer** (`lib/mood_bot/display.ex`): State machine managing refresh cycles, power saving, and display operations
- **Driver Layer** (`lib/mood_bot/display/driver.ex`): Protocol implementation with command sequences matching Python reference driver
- **HAL Interface** (`lib/mood_bot/display/hal.ex`): Behavior defining SPI/GPIO operations
- **MockHAL** (`lib/mood_bot/display/mock_hal.ex`): Development simulation with bitmap output
- **RpiHAL** (`lib/mood_bot/display/rpi_hal.ex`): Hardware implementation using Circuits libraries

**Reusable Components:**
- Complete initialization sequences following DRIVER.md specifications
- State machine with refresh timing (3-minute cycles, partial update limits)
- Error handling patterns with timeout management
- GPIO debugging utilities in IExHelpers
- SSH MCP remote debugging with direct function calls

**Integration Points:**
- OTP supervision tree integration
- Target-conditional HAL selection (host vs embedded)
- Interactive IEx access for hardware control and diagnostics
- SSH-Nerves testing capabilities during development

## Requirements

### Requirement 1: Python Reference Driver Compliance
**User Story:** As a hardware developer, I want the e-ink display to follow the exact Waveshare Python driver implementation, so that behavior is predictable and debugging can reference known working code.

##### Acceptance Criteria
1. WHEN display initializes THEN the system SHALL follow the exact GPIO pin configuration from DRIVER.md (RST:17, DC:25, CS:8, BUSY:24, PWR:18)
2. WHEN hardware reset occurs THEN the system SHALL execute the precise 50ms-2ms-50ms timing sequence
3. WHEN entering sleep mode THEN the system SHALL send deep sleep command (0x10) with data (0x01) followed by 2000ms delay
4. WHEN using circuits_gpio THEN the system SHALL follow documented best practices for GPIO management
5. WHEN using circuits_spi THEN the system SHALL implement proper SPI communication patterns per Elixir documentation

### Requirement 2: Hexdocs-Verified Implementation
**User Story:** As an Elixir developer, I want all Circuits library usage to be verified against hexdocs, so that implementation follows current best practices and API usage.

##### Acceptance Criteria
1. WHEN implementing GPIO operations THEN the system SHALL use circuits_gpio APIs as documented in hexdocs
2. WHEN implementing SPI communication THEN the system SHALL use circuits_spi patterns verified in hexdocs
3. WHEN handling GPIO errors THEN the system SHALL implement error handling patterns consistent with Circuits library documentation
4. WHEN managing SPI transfers THEN the system SHALL use appropriate transfer modes and configurations per hexdocs
5. IF API usage deviates from hexdocs THEN the implementation SHALL document the reasoning and provide references

### Requirement 3: Interactive IEx Control Interface
**User Story:** As a developer accessing a Nerves device via SSH, I want display control functions available in the IEx prompt, so that I can manually test and debug display operations.

##### Acceptance Criteria
1. WHEN accessing device via SSH THEN the system SHALL provide IEx functions for display on/off
2. WHEN in IEx session THEN the system SHALL provide functions to show test patterns on display
3. WHEN debugging hardware THEN the system SHALL provide diagnostic information functions in IEx
4. WHEN testing display operations THEN the system SHALL provide functions for partial vs full refresh testing
5. IF display errors occur THEN the system SHALL provide IEx functions to inspect error states and reset

### Requirement 4: SSH-Nerves Development Testing
**User Story:** As a developer, I want to run display tests through SSH-Nerves during development, so that hardware integration can be validated remotely without physical access.

##### Acceptance Criteria
1. WHEN running development tests THEN the system SHALL support SSH-Nerves test execution
2. WHEN testing display cycles THEN the system SHALL provide remote test functions for initialization/sleep sequences
3. WHEN validating GPIO states THEN the system SHALL support remote GPIO status checking
4. WHEN debugging SPI communication THEN the system SHALL provide remote SPI test capabilities
5. IF remote tests fail THEN the system SHALL provide detailed error information accessible via SSH

### Requirement 5: Consistent Display Update Cycles
**User Story:** As a user, I want display updates to work reliably with proper refresh management, so that the screen content is always clear and up-to-date.

##### Acceptance Criteria
1. WHEN performing partial updates THEN the system SHALL complete within 2-3 seconds
2. WHEN performing full refresh THEN the system SHALL complete within 15-20 seconds following Python driver timing
3. WHEN 5 partial updates have occurred THEN the system SHALL automatically trigger a full refresh
4. WHEN 3 minutes have elapsed THEN the system SHALL perform an automatic full refresh cycle
5. IF display operation times out THEN the system SHALL return to idle_and_ready state and log detailed error information

### Requirement 6: Development and Testing Support
**User Story:** As a developer, I want comprehensive testing and simulation capabilities that work without physical hardware, so that development can proceed efficiently on host systems.

##### Acceptance Criteria
1. WHEN running on host target THEN the system SHALL use MockHAL for all hardware operations
2. WHEN MockHAL processes image data THEN the system SHALL save viewable PBM bitmap files
3. WHEN debugging remotely THEN the system SHALL support direct function calls via SSH MCP
4. WHEN testing hardware connectivity THEN the system SHALL provide granular test functions (SPI, small data, large data)
5. IF hardware debugging is needed THEN the system SHALL provide GPIO status utilities accessible via IEx

## Alignment with Product Vision

This feature directly supports the product vision by:
- **Educational Value**: Demonstrates proper hardware driver implementation following industry standards and Python reference code
- **Real-World Interaction**: Provides tangible visual feedback through the e-ink display
- **Accessibility**: Comprehensive testing support enables learning without requiring physical hardware
- **Remote Development**: SSH-based testing enables development and debugging without physical device access
- **Industry Standards**: Uses established Elixir libraries (circuits_gpio, circuits_spi) with hexdocs-verified implementations