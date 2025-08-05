# Implementation Tasks
# Feature: working-display

## Overview

Break down the design into atomic, executable implementation tasks that enhance the existing display system for reliable operation. Tasks prioritize code reuse and build incrementally on the proven HAL architecture.

## Implementation Tasks

### Phase 1: Documentation and Type Specifications

- [x] 1. Add comprehensive documentation to Display GenServer
  - Add detailed `@moduledoc` with usage examples and state machine explanation
  - Add `@doc` annotations to all public functions with parameter descriptions
  - Add `@spec` type specifications for all public functions
  - Cross-reference Python driver URLs in function documentation
  - _Leverage: lib/mood_bot/display.ex (existing state machine and functions)_
  - _Requirements: 1.1, 2.1, 2.2_

- [x] 2. Add comprehensive documentation to Driver module
  - Add detailed `@moduledoc` explaining protocol implementation
  - Add `@doc` annotations to all functions with command explanations
  - Add `@spec` type specifications for all functions
  - Document timing constants and their sources from DRIVER.md
  - Cross-reference Python driver functions in documentation
  - _Leverage: lib/mood_bot/display/driver.ex (existing command implementations)_
  - _Requirements: 1.1, 2.1, 2.2_

- [x] 3. Enhance HAL behavior and implementations with documentation
  - Add comprehensive `@moduledoc` to HAL behavior explaining interface
  - Add detailed `@doc` and `@spec` to all callback definitions
  - Update MockHAL and RpiHAL with improved `@moduledoc` and function docs
  - Document GPIO pin mappings and SPI configuration requirements
  - _Leverage: lib/mood_bot/display/hal.ex, mock_hal.ex, rpi_hal.ex_
  - _Requirements: 2.1, 2.2, 2.5_

### Phase 2: Hexdocs Verification and Circuit Library Updates

- [x] 4. Verify circuits_gpio usage against hexdocs
  - Review RpiHAL GPIO operations against current circuits_gpio documentation
  - Update GPIO opening, reading, and writing patterns per hexdocs
  - Ensure proper error handling follows circuits_gpio patterns
  - Validate controller/offset tuple usage matches current API
  - _Leverage: lib/mood_bot/display/rpi_hal.ex (existing GPIO implementation)_
  - _Requirements: 2.1, 2.3_

- [x] 5. Verify circuits_spi usage against hexdocs
  - Review RpiHAL SPI operations against current circuits_spi documentation
  - Update SPI opening, transfer, and configuration patterns per hexdocs
  - Ensure chunked transfer implementation follows best practices
  - Validate SPI mode and speed configuration
  - _Leverage: lib/mood_bot/display/rpi_hal.ex (existing SPI implementation)_
  - _Requirements: 2.1, 2.4_

- [x] 6. Enhance error handling and logging
  - Improve error context in all HAL operations
  - Add structured logging with operation details for debugging
  - Implement consistent error tuple patterns across all modules
  - Add timeout handling with detailed error information
  - _Leverage: existing error handling patterns in display.ex and driver.ex_
  - _Requirements: 6.1, 6.2, 6.3_

### Phase 3: Configuration Enhancement

- [x] 7. Ensure GPIO configuration comes from application config
  - Verify Display GenServer reads GPIO pins from config/target.exs
  - Add configuration validation at HAL initialization
  - Improve error messages for invalid GPIO specifications
  - Test configuration loading with controller/offset tuples
  - _Leverage: existing configuration pattern in config/target.exs lines 100-110_
  - _Requirements: 1.1, 1.4_

- [x] 8. Add configuration validation and startup checks
  - Implement GPIO pin availability checking at startup
  - Validate SPI device existence and accessibility
  - Add clear error messages for configuration problems
  - Test with both valid and invalid configurations
  - _Leverage: existing HAL init functions in mock_hal.ex and rpi_hal.ex_
  - _Requirements: 1.4, 6.1_

### Phase 4: Interactive IEx Interface

- [ ] 9. Extend IExHelpers with display control functions
  - Add `display_on()` function for initialization and wake-up
  - Add `display_off()` function for sleep mode
  - Add `display_status()` function for state information
  - Add `display_clear()` and `display_fill_black()` functions
  - _Leverage: lib/mood_bot/iex_helpers.ex (existing helper pattern)_
  - _Requirements: 3.1, 3.2_

- [ ] 10. Add test pattern generation to IExHelpers
  - Add `display_test_pattern(pattern_type)` function with multiple patterns
  - Implement `:checkerboard`, `:horizontal_lines`, `:vertical_lines` patterns
  - Add `:border`, `:diagonal`, `:solid_black`, `:solid_white` patterns
  - Include pattern preview in function documentation
  - _Leverage: existing pattern generation in display.ex generate_mood_image functions_
  - _Requirements: 3.2, 3.4_

- [ ] 11. Add hardware diagnostic functions to IExHelpers
  - Add `display_gpio_status()` function to show GPIO pin states
  - Add `display_spi_test()` function for communication testing
  - Add `display_reset_errors()` function to clear error states
  - Add `display_run_diagnostics()` comprehensive test function
  - _Leverage: existing GPIO debugging in iex_helpers.ex and test functions in driver.ex_
  - _Requirements: 3.3, 3.5, 4.3, 4.4_

### Phase 5: SSH-Nerves Testing Support

- [ ] 12. Add remote test execution functions
  - Add `run_initialization_test()` for remote init sequence testing
  - Add `run_display_cycle_test()` for partial/full refresh cycle testing
  - Add `run_power_management_test()` for sleep/wake cycle testing
  - Include detailed result reporting for SSH access
  - _Leverage: existing test functions in driver.ex (test_spi_communication, etc.)_
  - _Requirements: 4.1, 4.2, 4.5_

- [ ] 13. Enhance remote debugging capabilities
  - Add `run_gpio_connectivity_test()` for GPIO pin validation
  - Add `run_spi_communication_test()` for SPI transfer validation
  - Improve error reporting to include hardware context
  - Add test result logging visible via SSH
  - _Leverage: existing test functions and GPIO debugging utilities_
  - _Requirements: 4.3, 4.4, 4.5_

### Phase 6: Testing and Validation

- [ ] 14. Test MockHAL bitmap generation improvements
  - Verify bitmap saving works with enhanced filenames
  - Test bitmap generation with various image patterns
  - Validate PBM file format and viewability
  - Test session ID generation and frame counting
  - _Leverage: existing MockHAL implementation in mock_hal.ex_
  - _Requirements: 6.1, 6.4_

- [ ] 15. Test hardware integration via SSH MCP
  - Test all IExHelpers functions via SSH MCP remote calls
  - Validate GPIO configuration loading from config/target.exs
  - Test error handling and recovery scenarios
  - Verify proper resource cleanup on errors
  - _Leverage: existing SSH MCP debugging capabilities_
  - _Requirements: 4.1, 4.2, 4.3, 4.4_

- [ ] 16. Validate Python driver compliance
  - Test initialization sequence timing against DRIVER.md specifications
  - Verify command sequences match Python reference driver
  - Test GPIO pin usage follows controller/offset tuple pattern
  - Validate sleep/wake cycles match Python behavior
  - _Leverage: existing driver implementation and timing constants_
  - _Requirements: 1.1, 1.2, 1.3, 5.2_

## Implementation Notes

**Critical Dependencies:**
- All tasks depend on existing HAL architecture remaining intact
- Configuration must come from config/target.exs, not hardcoded values
- Documentation must be developer-focused and brief
- All circuits_gpio/circuits_spi usage must follow hexdocs patterns

**Testing Strategy:**
- Use MockHAL for development testing without hardware
- Use SSH MCP for remote hardware testing
- Validate against Python driver behavior and timing
- Test both success and error scenarios thoroughly

**Compliance Requirements:**
- All functions must have proper `@doc` and `@spec` annotations
- GPIO pins must come from application configuration
- Error handling must provide detailed context for debugging
- Interactive functions must be accessible via SSH IEx sessions