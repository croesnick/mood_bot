# Requirements Document: Display-Driver-HAL Architecture Refactoring

## Introduction

This refactoring addresses the current architectural inconsistencies in the display subsystem to achieve clear separation of concerns between the Display (GenServer), Driver (protocol implementation), and HAL (hardware abstraction) layers. The current mixed ownership pattern where Display manages HAL state but Driver operates on it creates maintenance challenges and violates clean architecture principles.

## Alignment with Product Vision

This refactoring directly supports MoodBot's educational goals by:

- **Demonstrating Clean Architecture**: Aligns with the product's educational mission to teach proper software design patterns
- **Improving Hardware Abstraction**: Enhances the HAL pattern that is central to MoodBot's cross-platform development approach
- **Enabling Extensibility**: Supports the primary success metric by making it easier to extend hardware functionality
- **Maintaining Educational Value**: Preserves the didactic approach by creating clearer, more understandable module boundaries

## Codebase Analysis Summary

**Existing Patterns to Leverage:**

- **TypedStruct Pattern**: MockHAL and RpiHAL already use TypedStruct for state management
- **Behavior Implementation**: HAL behavior pattern is well-established with MockHAL and RpiHAL implementations  
- **GenServer State Management**: Display module provides excellent pattern for stateful hardware management
- **Target-Conditional Logic**: Mix.target() pattern for platform-specific HAL selection
- **Comprehensive Error Handling**: Consistent {:ok, state} | {:error, reason} patterns throughout codebase
- **Test Infrastructure**: DisplayTestHelper and TestHAL provide solid testing patterns

**Integration Points:**

- Display.status/1 must continue to expose HAL module information for debugging
- Application.ex supervision tree registration remains unchanged
- Configuration loading from config/target.exs and config/host.exs
- All public Display API functions maintain backward compatibility

## Requirements

### Requirement 1: Clean Dependency Architecture

**User Story:** As a developer maintaining the display subsystem, I want clear separation of concerns between Display, Driver, and HAL layers, so that changes to hardware implementation don't affect business logic and the code is easier to understand and maintain.

#### Acceptance Criteria

1. WHEN initializing the display system THEN Display SHALL call Driver.init/1 with configuration AND Driver SHALL handle all HAL lifecycle management internally
2. WHEN performing display operations THEN Display SHALL only call Driver functions with driver_state AND Driver SHALL manage all HAL interactions internally
3. WHEN terminating the display system THEN Display SHALL call Driver.close/1 AND Driver SHALL handle HAL resource cleanup
4. IF any Driver operation fails THEN Driver SHALL return {:error, reason} to Display AND Display SHALL not directly access HAL state

### Requirement 2: Driver State Ownership

**User Story:** As a developer extending the display functionality, I want the Driver module to own HAL lifecycle and state management, so that HAL implementation details are properly encapsulated and the architecture follows single responsibility principles.

#### Acceptance Criteria

1. WHEN Driver.init/1 is called THEN Driver SHALL select appropriate HAL module based on Mix.target() AND initialize HAL state internally
2. WHEN any Driver function is called THEN Driver SHALL accept driver state as first parameter AND return updated driver state
3. WHEN Driver functions complete successfully THEN Driver SHALL return {:ok, new_driver_state} AND encapsulate any HAL state changes
4. IF HAL operations fail THEN Driver SHALL handle HAL errors AND return appropriate error tuples to Display

### Requirement 3: Display State Simplification

**User Story:** As a developer working with the Display GenServer, I want the Display module to focus solely on business logic and state management, so that display timing, refresh cycles, and power management are separated from hardware protocol details.

#### Acceptance Criteria

1. WHEN Display GenServer starts THEN Display SHALL store only driver_state AND remove hal_module and hal_state from its internal state
2. WHEN Display operations are called THEN Display SHALL validate business logic constraints AND delegate hardware operations to Driver
3. WHEN Driver operations return THEN Display SHALL update its driver_state AND maintain all timing and refresh cycle logic
4. IF Display terminate is called THEN Display SHALL call Driver.close/1 AND not directly interact with HAL

### Requirement 4: HAL Selection Abstraction

**User Story:** As a developer deploying to different platforms, I want HAL module selection to be transparent and handled by the Driver layer, so that platform-specific logic is properly encapsulated and configuration is simplified.

#### Acceptance Criteria

1. WHEN Driver.init/1 is called THEN Driver SHALL automatically select MockHAL for Mix.target() == :host AND RpiHAL for embedded targets
2. WHEN configuration is passed to Driver THEN Driver SHALL not require hal_module specification AND determine HAL module internally
3. WHEN different HAL implementations are needed THEN Driver SHALL provide configuration options without exposing HAL details to Display
4. IF HAL selection fails THEN Driver SHALL return clear error messages AND not expose HAL implementation details

### Requirement 5: Backward Compatibility

**User Story:** As a user of the MoodBot system, I want the display functionality to continue working exactly as before, so that the refactoring doesn't break existing functionality or require changes to application-level code.

#### Acceptance Criteria

1. WHEN Display public API functions are called THEN Display SHALL provide identical behavior to current implementation AND maintain all existing function signatures
2. WHEN Display.status/1 is called THEN Display SHALL include hal_module information from driver state AND preserve debugging capabilities
3. WHEN application configuration is loaded THEN Display SHALL accept same configuration format AND handle hal_module configuration gracefully
4. IF existing tests are run THEN all Display behavior tests SHALL pass AND integration tests SHALL pass with minimal changes

### Requirement 6: Critical Path Testing

**User Story:** As a developer ensuring system reliability, I want focused test coverage on critical paths for the refactored architecture, so that core functionality is validated and regressions in essential operations are prevented.

#### Acceptance Criteria

1. WHEN Driver initialization is tested THEN Driver.init/1 SHALL be validated with both MockHAL and error scenarios AND HAL selection logic SHALL be verified
2. WHEN Display core operations are tested THEN init_display, show_mood, clear, and sleep functions SHALL continue to work AND existing Display integration tests SHALL pass
3. WHEN error handling is tested THEN Driver failures SHALL propagate correctly to Display AND HAL errors SHALL be handled gracefully
4. IF critical path tests fail THEN clear error messages SHALL indicate whether failure is in Display, Driver, or HAL layer

## Non-Functional Requirements

### Performance

- Refactoring SHALL NOT introduce measurable performance degradation in display operations
- Driver state transitions SHALL remain as efficient as current HAL state management
- Memory usage SHALL not increase significantly due to architectural changes

### Maintainability

- Each layer SHALL have single, clear responsibility as defined in tech.md
- Driver interface SHALL be stable and minimize future changes to Display layer
- Error messages SHALL clearly indicate which layer (Display/Driver/HAL) encountered issues

### Reliability

- All hardware resource cleanup SHALL remain robust during system shutdown
- Error recovery patterns SHALL be preserved at appropriate layers
- HAL operation failures SHALL be handled gracefully without system crashes

### Testability  

- Driver layer SHALL be unit testable independently of Display GenServer
- HAL implementations SHALL remain mockable for development testing
- Integration test patterns SHALL be preserved and enhanced where possible
