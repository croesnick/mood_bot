# Implementation Tasks: Display-Driver-HAL Architecture Refactoring

## Phase 1: Driver State Structure Setup

- [x] 1. Add TypedStruct to Driver module
  - Import `use TypedStruct` at top of `lib/mood_bot/display/driver.ex`
  - Add typedstruct definition with hal_module, hal_state, initialized? fields
  - Define @type driver_state() specification
  - _Leverage: lib/mood_bot/display/mock_hal.ex typedstruct pattern, lib/mood_bot/display/rpi_hal.ex structure_
  - _Requirements: 2.1, 2.2_

- [x] 2. Implement Driver.init/1 with HAL selection
  - Create new `init/1` function that takes config map as parameter
  - Add `select_hal_module/0` private function using Mix.target() logic
  - Initialize selected HAL module and create driver state
  - Update function spec to return `{:ok, driver_state()} | {:error, term()}`
  - _Leverage: lib/mood_bot/display.ex set_hal_module pattern (lines 1181-1188), existing HAL init patterns_
  - _Requirements: 2.1, 4.1_

- [x] 3. Update Driver function signatures
  - Update all Driver functions to accept driver_state as first parameter
  - Change return types to `{:ok, driver_state()} | {:error, term()}`
  - Update function specs: init, display_frame_full, display_frame_partial, clear_display, sleep
  - Update helper functions: reset, wait_until_idle, send_command, send_data, set_memory_area, set_memory_pointer
  - _Leverage: lib/mood_bot/display/hal.ex callback patterns for consistent error handling_
  - _Requirements: 2.2, 2.3_

## Phase 2: Driver Function Implementation

- [x] 4. Update Driver.init/1 implementation
  - Replace current `init(hal, hal_state)` with new `init(config)` implementation
  - Call HAL init internally and wrap state in driver_state
  - Add error handling for HAL initialization failures
  - _Leverage: current Driver.init function logic (lines 157-195), HAL error patterns_
  - _Requirements: 2.1, 2.4_

- [x] 5. Update core display functions
  - Update `display_frame_full/2`, `display_frame_partial/2`, `clear_display/2`
  - Extract HAL module and state from driver_state parameter
  - Call HAL functions and wrap results back into driver_state
  - Maintain all existing protocol logic
  - _Leverage: current function implementations, preserve exact command sequences_
  - _Requirements: 2.2, 2.3_

- [x] 6. Update utility and test functions
  - Update `sleep/1`, `test_spi_communication/1`, `test_small_data_write/1`, `test_large_data_write/2`
  - Update helper functions: `reset/1`, `wait_until_idle/1`, `send_command/2`, `send_data/2`
  - Update memory management functions: `set_memory_area/5`, `set_memory_pointer/3`
  - _Leverage: existing function logic, maintain exact timing and protocol requirements_
  - _Requirements: 2.2, 2.3_

- [x] 7. Add Driver.close/1 function
  - Create new `close/1` function that takes driver_state
  - Call HAL close function to cleanup resources
  - Return `:ok` (no state to return on close)
  - Add proper error logging without propagating errors
  - _Leverage: lib/mood_bot/display/rpi_hal.ex close function pattern (lines 249-261)_
  - _Requirements: 2.3, 3.4_

## Phase 3: Display State Updates

- [x] 8. Update Display defstruct
  - Remove `:hal_module` and `:hal_state` fields from defstruct
  - Add `:driver_state` field to defstruct
  - Update Display state type definitions and documentation
  - _Leverage: existing defstruct pattern (lines 143-157), preserve all other fields_
  - _Requirements: 3.1, 3.2_

- [x] 9. Update Display.init callback
  - Replace `state.hal_module.init(config)` call with `Driver.init(config)`
  - Replace `Driver.init(state.hal_module, state.hal_state)` with single Driver.init call
  - Update state initialization to store driver_state instead of hal_module/hal_state
  - _Leverage: existing GenServer init pattern (lines 466-516), preserve error handling_
  - _Requirements: 1.1, 3.1_

- [x] 10. Update Display function implementations - Part 1
  - Update `handle_call(:init_display, ...)` to use Driver with driver_state
  - Update `handle_call(:clear, ...)` and `handle_call(:fill_black, ...)`
  - Replace `Driver.func(state.hal_module, state.hal_state, ...)` calls
  - Update state with returned driver_state from Driver calls
  - _Leverage: existing handle_call patterns, preserve business logic and validation_
  - _Requirements: 1.2, 3.2, 3.3_

- [x] 11. Update Display function implementations - Part 2
  - Update `handle_call({:display_image, ...}, ...)` and `handle_call({:show_mood, ...}, ...)`
  - Update `handle_call(:sleep, ...)` and test functions
  - Update `handle_info(:auto_refresh, ...)` and `handle_info(:power_save, ...)`
  - _Leverage: existing business logic, preserve refresh cycles and timing_
  - _Requirements: 1.2, 3.2, 3.3_

- [x] 12. Update Display helper functions
  - Update `perform_full_refresh_update/2` and `perform_partial_refresh_update/2`
  - Update `handle_display_operation/2` to work with driver_state
  - Update state management functions to use driver_state
  - _Leverage: existing helper function patterns (lines 1038-1101)_
  - _Requirements: 3.2, 3.3_

- [x] 13. Update Display.terminate callback
  - Replace direct `state.hal_module.close(state.hal_state)` with `Driver.close(state.driver_state)`
  - Preserve timer cancellation and cleanup logic
  - _Leverage: existing terminate pattern (lines 973-990)_
  - _Requirements: 3.4_

- [x] 14. Update Display.status/1 function
  - Extract hal_module from driver_state for debugging compatibility
  - Update status map to include hal_module from driver_state
  - Preserve all other status information and formatting
  - _Leverage: existing status function (lines 856-891), maintain debugging capabilities_
  - _Requirements: 5.2_

## Phase 4: Testing Updates

- [x] 15. Update Driver tests
  - Modify `test/mood_bot/display/driver_test.exs` to use new Driver.init/1 interface
  - Update test setup to create driver_state instead of using HAL directly
  - Update all test assertions to work with driver_state returns
  - Add test for HAL selection logic (MockHAL vs RpiHAL)
  - _Leverage: test/support/display_test_helper.ex TestHAL patterns, existing test structure_
  - _Requirements: 6.1, 6.4_

- [x] 16. Verify Display tests still pass
  - Run existing Display tests in `test/mood_bot/display_test.exs`
  - Update any failing tests to work with new architecture
  - Ensure all public API tests continue to pass without modification
  - Verify status/1 function still exposes hal_module for debugging
  - _Leverage: existing test patterns should work with minimal changes_
  - _Requirements: 5.1, 5.4, 6.2_

- [x] 17. Add critical path error handling tests
  - Add test for Driver initialization failures and error propagation
  - Add test for HAL operation failures and Display error handling
  - Add test for resource cleanup during failures
  - Verify clear error attribution between Display, Driver, and HAL layers
  - _Leverage: existing error handling test patterns in display tests_
  - _Requirements: 6.3, 6.4_

## Phase 5: Integration and Validation

- [x] 18. Run comprehensive test suite
  - Execute `mix test` to ensure all tests pass
  - Run `mix format` to ensure code formatting consistency
  - Run `mix credo --strict` to check code quality
  - Fix any issues discovered in testing
  - _Leverage: existing development workflow from CLAUDE.md_
  - _Requirements: 5.4_

- [x] 19. Validate backward compatibility
  - Test all public Display API functions work identically
  - Verify Display.status/1 still provides debugging information
  - Test configuration loading still works with existing config files
  - Ensure no breaking changes to public interfaces
  - _Leverage: existing integration tests and API patterns_
  - _Requirements: 5.1, 5.2, 5.3_

- [x] 20. Platform validation
  - Test on host platform (MockHAL selection and functionality)
  - Test HAL selection logic works correctly for different Mix.target() values
  - Verify error messages are clear and helpful
  - Document any discovered issues or edge cases
  - _Leverage: existing host/target testing patterns_
  - _Requirements: 4.1, 4.4_