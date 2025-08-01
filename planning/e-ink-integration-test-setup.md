# E-ink Display Integration Testing System

## Executive Summary

Develop an automated integration testing system for an Elixir + Nerves project that validates e-ink display output using camera-based verification. The system will use Model Context Protocol (MCP) servers for device control and image processing, with heatmap-based comparison to detect display differences.

## Objectives

### Primary Goals

1. **Automated Visual Verification**: Capture and verify that e-ink displays show the expected content
2. **Integration Testing Pipeline**: Enable automated testing of firmware deployments and display updates
3. **Diagnostic Insights**: Provide detailed analysis of display differences with visual heatmaps
4. **Development Workflow**: Support both interactive development (Claude Code + MCPs) and automated testing (ExUnit)

### Success Criteria

- **Accuracy**: >95% correct identification of display issues
- **Performance**: Complete test cycle in <60 seconds (including 15s e-ink refresh)
- **Reliability**: <5% false positives due to environmental factors
- **Usability**: Visual heatmaps clearly indicate problem areas

## System Architecture

### High-Level Components

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Claude Code   │    │   ExUnit Tests  │    │  Test Hardware  │
│  (Interactive)  │    │  (Automated)    │    │                 │
└─────────┬───────┘    └─────────┬───────┘    │ ┌─────────────┐ │
          │                      │            │ │ Raspberry Pi│ │
          └──────────┬───────────┘            │ │ + E-ink     │ │
                     │                        │ └─────────────┘ │
         ┌───────────▼───────────┐            │ ┌─────────────┐ │
         │    Elixir Test        │            │ │   Camera    │ │
         │    Orchestrator       │◄───────────┤ │ (head-down) │ │
         └───────────┬───────────┘            │ └─────────────┘ │
                     │                        └─────────────────┘
    ┌────────────────┼────────────────┐
    │                │                │
┌───▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐
│SSH MCP   │  │Camera MCP   │  │OpenCV MCP   │
│Server    │  │Server       │  │Server       │
│          │  │             │  │             │
│- Deploy  │  │- Capture    │  │- Process    │
│- Control │  │- Configure  │  │- Compare    │
│- Monitor │  │- Stream     │  │- Heatmaps   │
└──────────┘  └─────────────┘  └─────────────┘
```

## E-ink Display Characteristics

### Physical Specifications

- **Resolution**: 128x296 pixels (37,888 total pixels)
- **Display Type**: Monochrome e-ink (black/white)
- **Pixel Size**: ~0.27mm per pixel (estimated based on typical e-ink displays)
- **Active Area**: Approximately 3.5cm x 8cm

### Testing Implications for Small Display

1. **Pixel-Level Precision Required**
   - Every pixel matters at 128-pixel width
   - Sub-pixel text rendering needs careful analysis
   - 1-pixel differences are significant (0.78% of width)

2. **Camera Setup Challenges**
   - Must achieve sharp focus on small area
   - Higher magnification may be needed
   - Vibration/movement more critical due to scale
   - Lighting must be very even across small surface

3. **Comparison Algorithm Adaptations**
   - Tighter similarity thresholds required
   - Grid analysis cells are very small (16x37 pixels each)
   - Text detection algorithms need sub-pixel accuracy
   - Ghosting artifacts more visually prominent

4. **Processing Advantages**
   - Much faster image processing due to small size
   - Lower memory requirements
   - Faster comparison operations
   - Quick test cycles possible

### Hardware Setup

1. **Raspberry Pi** with Elixir + Nerves + e-ink display
   - **E-ink Display**: 128x296 pixels (37,888 total pixels)
   - **Display Area**: Approximately 3.5cm x 8cm (varies by manufacturer)
2. **Camera** positioned head-down towards e-ink display
   - Minimum 1080p resolution (4K recommended for precise pixel analysis)
   - **Critical**: Camera must capture fine detail for 128-pixel width analysis
   - Fixed mounting with minimal vibration
   - Consistent lighting (500-1000 lux, 5000K-6500K LEDs)
   - 45-90° angle positioning with optional polarizing filter
   - **Focus distance**: Optimized for small display area (likely 15-30cm)

### Software Stack

1. **Elixir Testing Framework**
   - Built on ExUnit
   - Integration with MCP servers
   - Support for interactive Claude Code sessions

2. **MCP Servers** (existing, to be integrated):
   - **SSH Control**: ClassFang's ssh-mcp-server or similar
   - **Camera Capture**: 13rac1's videocapture-mcp
   - **Image Processing**: GongRzhe's opencv-mcp-server

3. **Image Processing Pipeline**
   - Camera capture and preprocessing
   - Skew correction and normalization
   - Heatmap-based comparison
   - Region analysis and classification

## Implementation Phases

### Phase 0: MCP Server Evaluation (Week 1)

**CRITICAL**: Validate camera and image processing MCP servers are suitable for our use case. SSH MCP (tufantunc/ssh-mcp) is already validated and working.

#### Evaluation Objectives

Determine if remaining MCP servers can handle:

1. **Real-time performance** requirements for testing workflows
2. **Large image processing** operations efficiently  
3. **Camera hardware reliability** with consistent capture
4. **Error handling** for hardware failures and timing issues
5. **Latency overhead** acceptable for development workflows

#### Evaluation Test Cases

**✅ SSH MCP - VALIDATED**

- **Status**: Already using tufantunc/ssh-mcp successfully
- **Capabilities**: Firmware deployment, command execution, file transfer
- **Skip evaluation**: Proceed directly to implementation

**Test Case 1: Camera MCP Reliability**

```elixir
defmodule MCPEvaluation.CameraTest do
  def evaluate_camera_mcp() do
    test_scenarios = [
      {:single_capture, resolution: "1920x1080"},
      {:rapid_capture, count: 10, interval: 500},
      {:format_support, formats: ["png", "jpg", "bmp"]},
      {:error_recovery, simulate: [:disconnect, :busy, :timeout]},
      {:head_down_mounting, test: "camera_positioning"}
    ]
    
    # Success criteria:
    # - Capture latency: <2 seconds
    # - Image quality: no corruption or artifacts
    # - Error handling: clear error messages + recovery
    # - Resource usage: <100MB memory per capture
    # - Consistent focus/exposure for e-ink displays
  end
end
```

**Test Case 2: OpenCV MCP Image Processing**

```elixir
defmodule MCPEvaluation.OpenCVTest do
  def evaluate_opencv_mcp() do
    test_pipeline = [
      {:load_image, "camera_capture_1080p.png"},
      {:crop_operation, bbox: "auto_detect_128x296_display"},
      {:resize_to_display, target: {128, 296}},
      {:perspective_correct, angle: 15},
      {:grayscale_convert},
      {:difference_heatmap, expected: "reference_128x296.png"},
      {:save_result, format: "png"}
    ]
    
    # Success criteria (adjusted for small display):
    # - Processing time: <2 seconds for full pipeline (much smaller than 4K)
    # - Memory usage: <128MB peak (display is only 37,888 pixels)
    # - Quality: no processing artifacts on 128-pixel width
    # - Batch operations: can chain multiple operations
    # - Heatmap generation: accurate difference visualization at pixel level
    # - Precision: handle 1-pixel differences (critical for small display)
  end
end
```

**Test Case 3: End-to-End Integration**

```elixir
defmodule MCPEvaluation.IntegrationTest do
  def evaluate_full_workflow() do
    # Simulate complete testing workflow
    workflow = [
      {:ssh_deploy, firmware: "test.fw", via: :validated_ssh_mcp},
      {:ssh_trigger, command: "update_display", via: :validated_ssh_mcp},
      {:wait_refresh, duration: 15_000},
      {:camera_capture, retries: 3, via: :camera_mcp_under_test},
      {:opencv_process, pipeline: [:crop, :correct, :compare], via: :opencv_mcp_under_test},
      {:analyze_results, threshold: 0.9}
    ]
    
    # Success criteria:
    # - Total time: <60 seconds
    # - Reliability: >95% success rate over 20 runs
    # - Error recovery: graceful handling of camera/processing failures
    # - Resource cleanup: no memory leaks
  end
end
```

#### MCP Server Alternatives Evaluation

**Camera MCP Candidates:**

- **Primary**: 13rac1/videocapture-mcp
- **Alternative**: Direct Picam library integration
- **Evaluation focus**: Reliability, latency, image quality

**OpenCV MCP Candidates:**

- **Primary**: GongRzhe/opencv-mcp-server  
- **Alternative**: Direct Evision library integration
- **Evaluation focus**: Processing speed, memory usage, feature completeness

#### Evaluation Deliverables

1. **MCP Performance Report** (Camera + OpenCV only)
   - Latency measurements for each operation
   - Memory and CPU usage profiles
   - Error handling assessment
   - Reliability statistics (success rate over multiple runs)

2. **Comparison Matrix**

   ```elixir
   %{
     ssh_operations: %{
       status: :validated, # Already using tufantunc/ssh-mcp
       notes: "Working well for firmware deployment and commands"
     },
     image_processing: %{
       mcp_performance: {:time, :reliability, :ease_of_use},
       direct_library: {:time, :reliability, :ease_of_use},
       recommendation: :mcp | :direct | :hybrid
     },
     camera_control: %{
       mcp_performance: {:time, :reliability, :ease_of_use},
       direct_library: {:time, :reliability, :ease_of_use},
       recommendation: :mcp | :direct | :hybrid
     }
   }
   ```

3. **Go/No-Go Decision Document**

   ```markdown
   ## MCP Server Viability Assessment
   
   ### SSH MCP: ✅ VALIDATED (tufantunc/ssh-mcp)
   - Status: Already in use and working
   - Performance: Meets requirements
   - Reliability: Proven in practice
   
   ### Camera MCP: ✅ RECOMMENDED / ❌ NOT SUITABLE / ⚠️ HYBRID
   - Performance: [results]
   - Reliability: [results]  
   - Issues found: [list]
   - Mitigation: [approach]
   
   ### OpenCV MCP: [decision]
   
   ### Final Architecture Recommendation:
   - SSH: Use existing tufantunc/ssh-mcp
   - Camera: [MCP/Direct/Hybrid based on evaluation]
   - Image Processing: [MCP/Direct/Hybrid based on evaluation]
   ```

#### Exit Criteria for Phase 0

**Proceed with MCP Architecture if:**

- [x] SSH operations working (already validated)
- [ ] Camera capture works reliably with <5% failure rate
- [ ] Image processing handles 4K images in <5 seconds
- [ ] Error recovery works for camera and processing failure modes
- [ ] Overall workflow completes in <60 seconds

**Switch to Alternative if:**

- [ ] Camera MCP has >20% failure rate
- [ ] OpenCV MCP performance more than 2x slower than direct libraries
- [ ] Critical features missing or buggy for camera/processing
- [ ] Error handling inadequate for hardware testing

**Known Good Foundation:**

- [x] SSH MCP (tufantunc) validated and ready to use
- [ ] Camera backend TBD (MCP vs Direct)  
- [ ] Image processing backend TBD (MCP vs Direct)

**Risk Mitigation:**

- [ ] Alternative implementations ready for each component
- [ ] Clear criteria for switching approaches mid-project
- [ ] Hybrid architecture patterns defined

### Phase 1: Core Infrastructure (Week 2-3)

#### Deliverables

1. **EinkTester Module** (Architecture-agnostic interface)

   ```elixir
   defmodule MyApp.EinkTester do
     @doc "Capture image from mounted camera"
     def capture_image(opts \\ [])
     
     @doc "Process raw camera image for comparison"
     def process_image(raw_image, processing_steps)
     
     @doc "Generate expected bitmap from application state"
     def generate_expected(display_content)
     
     @doc "Compare images and generate heatmap"
     def compare_with_heatmap(expected, actual, opts \\ [])
     
     @doc "Deploy firmware to target device"
     def deploy_firmware(target, firmware_path)
   end
   ```

2. **Adaptive Backend Layer** (Chosen based on Phase 0 results)

   ```elixir
   defmodule MyApp.BackendAdapter do
     # Will implement one of these based on evaluation:
     
     # Option A: MCP-based implementation
     defmodule MCPBackend do
       def ssh_execute(command, target)
       def camera_capture(camera_id, opts)
       def opencv_process(operation, image_data, params)
     end
     
     # Option B: Direct library implementation
     defmodule DirectBackend do
       def ssh_execute(command, target) # via SSHex
       def camera_capture(camera_id, opts) # via Picam
       def opencv_process(operation, image_data, params) # via Evision
     end
     
     # Option C: Hybrid implementation
     defmodule HybridBackend do
       # Use best-performing option for each operation
     end
   end
   ```

3. **Basic ExUnit Test Structure**

   ```elixir
   defmodule MyApp.EinkDisplayTest do
     use ExUnit.Case
     alias MyApp.EinkTester
     
     @moduletag :hardware_in_loop
     @moduletag timeout: 120_000  # 2 minutes for e-ink refresh
     
     setup do
       # Ensure clean state
       EinkTester.clear_display()
       Process.sleep(2000)
       :ok
     end
   end
   ```

#### Acceptance Criteria

- [ ] Backend adapter successfully chosen based on Phase 0 evaluation results
- [ ] Successfully deploy firmware to Raspberry Pi via chosen backend
- [ ] Capture images from mounted camera with <2 second latency
- [ ] Generate basic difference images with chosen image processing backend
- [ ] Run simple ExUnit test that deploys + captures + compares
- [ ] Fallback mechanisms work if primary backend fails during operation

### Phase 2: Image Processing Pipeline (Week 4)

#### Deliverables (Implementation depends on Phase 0 results)

1. **Image Preprocessing** (Will use chosen backend from Phase 0)

   ```elixir
   defmodule MyApp.ImageProcessor do
     @doc "Complete preprocessing pipeline using optimal backend"
     def preprocess_camera_image(raw_image) do
       raw_image
       |> crop_display_area()
       |> correct_perspective()
       |> normalize_lighting()
       |> convert_grayscale()
     end
     
     @doc "Detect if e-ink is still refreshing"
     def detect_refresh_state(image)
     
     @doc "Crop to display area using edge detection"
     def crop_display_area(image)
   end
   ```

2. **Heatmap Comparison**

   ```elixir
   defmodule MyApp.ImageComparison do
     @doc "Generate difference heatmap"
     def generate_heatmap(expected, actual, opts \\ [])
     
     @doc "Analyze difference regions"
     def analyze_regions(heatmap, threshold \\ 25)
     
     @doc "Calculate similarity metrics"
     def calculate_metrics(expected, actual)
   end
   ```

3. **E-ink Specific Features**

   ```elixir
   defmodule MyApp.EinkAnalyzer do
     @doc "Detect ghosting from previous display state"
     def detect_ghosting(previous_state, current_state)
     
     @doc "Wait for display refresh completion"
     def wait_for_stable_display(timeout \\ 20_000)
     
     @doc "Analyze partial vs full refresh artifacts"
     def analyze_refresh_artifacts(image)
   end
   ```

#### Acceptance Criteria

- [ ] Camera image accurately cropped to display area
- [ ] Perspective correction handles ±15° camera angles
- [ ] Heatmap clearly shows difference regions
- [ ] SSIM similarity scores >0.95 for identical content
- [ ] Ghosting detection identifies previous content artifacts

### Phase 3: Testing Framework Integration (Week 5)

#### Deliverables (Adapted to chosen architecture)

1. **Test Assertion Helpers**

   ```elixir
   defmodule MyApp.EinkAssertions do
     @doc "Assert images are similar within tolerance"
     def assert_images_similar(expected, actual, opts \\ [])
     
     @doc "Assert specific regions match"
     def assert_regions_match(expected, actual, regions)
     
     @doc "Assert no ghosting artifacts"
     def assert_no_ghosting(previous, current)
   end
   ```

2. **Interactive Interface** (Will adapt to available backend)

   ```elixir
   defmodule MyApp.InteractiveTester do
     @doc "Run test interactively with live feedback"
     def interactive_test(test_name, params \\ [])
     
     @doc "Show analysis in terminal (adapted to backend capabilities)"
     def show_analysis(comparison_result)
     
     @doc "Save test artifacts for debugging"
     def save_debug_artifacts(test_run)
   end
   ```

#### Note on Claude Code Integration

- **If MCP backend chosen**: Full Claude Code integration with real-time MCP calls
- **If direct library backend**: Claude Code generates ExUnit tests, limited real-time interaction
- **If hybrid backend**: Claude Code uses MCPs where available, falls back to code generation

### Phase 4: Production Readiness (Week 6)

#### Deliverables

1. **Configuration Management**

   ```elixir
   # config/test.exs
   config :my_app, MyApp.EinkTester,
     camera_settings: %{
       resolution: "1920x1080",
       camera_id: 0,
       capture_delay: 500
     },
     comparison_thresholds: %{
       similarity_min: 0.92,
       region_similarity_min: 0.85,
       ghosting_tolerance: 0.05
     },
     hardware_targets: %{
       default: "pi@192.168.1.100",
       staging: "pi@192.168.1.101"
     }
   ```

2. **Error Handling & Retry Logic**

   ```elixir
   defmodule MyApp.TestResilience do
     @doc "Retry logic for flaky hardware operations"
     def retry_with_backoff(operation, max_attempts \\ 3)
     
     @doc "Handle e-ink refresh timing variations"
     def adaptive_wait_for_refresh()
     
     @doc "Graceful degradation for MCP server failures"
     def fallback_to_direct_ssh(operation)
   end
   ```

3. **CI/CD Integration**
   - Test tags for different hardware setups
   - Artifact collection for failed tests
   - Integration with deployment pipelines

#### Acceptance Criteria

- [ ] Tests handle hardware timing variations gracefully
- [ ] Clear error messages for common failure modes
- [ ] CI/CD integration working
- [ ] Documentation complete for setup and usage

## Technical Specifications

### Image Processing Requirements

#### Camera Capture

- **Resolution**: 1920x1080 minimum, 4K preferred (for precise 128x296 pixel analysis)
- **Format**: PNG for lossless capture
- **Color Space**: RGB with grayscale conversion
- **Capture Timing**: 500ms delay after display update trigger
- **Focus Requirements**: Sharp focus on small 128x296 pixel area (~3.5cm x 8cm)
- **Pixel Density**: Camera must resolve individual e-ink pixels clearly

#### Preprocessing Pipeline

1. **Display Detection**: Automatic edge detection for 128x296 display boundaries
2. **Crop to Display**: Extract exact 128x296 pixel region from camera image
3. **Perspective Correction**: Handle ±15° rotation and ±10° skew
4. **Scaling**: Resize cropped region to exactly 128x296 pixels
5. **Lighting Normalization**: Histogram equalization and contrast adjustment
6. **Noise Reduction**: Minimal blur (0.5-1 pixel radius) to avoid detail loss

#### Comparison Thresholds (Adjusted for Small Display)

- **Overall Similarity (SSIM)**: >0.95 for pass, <0.90 for fail (higher threshold due to small size)
- **Pixel Difference**: <2% pixels with >15 intensity difference (tighter tolerance)
- **Critical Pixel Accuracy**: Every pixel matters at 128x296 resolution
- **Region Analysis**: Grid-based 8x6 analysis (16x37 pixels per grid cell)
- **Ghosting Detection**: <3% similarity with previous state in non-updated regions
- **Text Readability**: Special attention to sub-pixel text rendering

### MCP Server Requirements

#### SSH MCP Server Features Required

- [ ] Command execution with output capture
- [ ] File transfer (SCP) support
- [ ] Connection persistence and reuse
- [ ] Error handling and retry logic
- [ ] Multi-target support (dev/staging/prod)

#### Camera MCP Server Features Required

- [ ] Device enumeration and selection
- [ ] Resolution and format configuration
- [ ] Immediate capture and streaming modes
- [ ] Image metadata capture (timestamp, settings)

#### OpenCV MCP Server Features Required

- [ ] Image loading and format conversion
- [ ] Geometric transformations (crop, rotate, perspective)
- [ ] Comparison operations (SSIM, template matching)
- [ ] Visualization (heatmaps, annotations)
- [ ] Batch processing support

### Performance Requirements

#### Timing Constraints (Adjusted for 128x296 Display)

- **Total Test Duration**: <45 seconds per test case (reduced due to faster processing)
- **Image Capture**: <2 seconds from trigger
- **Image Processing**: <2 seconds for full pipeline (much smaller than originally assumed)
- **E-ink Refresh Wait**: 15-20 seconds (hardware limitation, unchanged)
- **Comparison Analysis**: <1 second for heatmap generation (37,888 pixels vs millions)

#### Resource Limits (Adjusted for Small Display)

- **Memory Usage**: <128MB peak during image processing (down from 512MB)
- **Disk Space**: <50MB for test artifacts per run (smaller images)
- **CPU Usage**: <60% during processing bursts (lighter processing load)
- **Network**: <5MB transfer per test (much smaller images + commands)

### Error Handling Requirements

#### Failure Modes to Handle

1. **Hardware Failures**
   - Camera disconnection or failure
   - Raspberry Pi network disconnection
   - E-ink display hardware issues

2. **Timing Issues**
   - E-ink refresh timeout
   - Network latency variations
   - MCP server response delays

3. **Image Quality Issues**
   - Poor lighting conditions
   - Camera focus problems
   - Perspective distortion

4. **Software Failures**
   - MCP server crashes
   - Image processing errors
   - Deployment failures

#### Recovery Strategies

- **Retry Logic**: 3 attempts with exponential backoff
- **Fallback Methods**: Direct SSH if MCP fails
- **Graceful Degradation**: Skip comparison if capture fails
- **Clear Error Messages**: Actionable feedback for each failure type

## Testing & Validation

### Unit Tests Required

- [ ] Image processing functions (crop, rotate, compare)
- [ ] MCP client communication
- [ ] Configuration validation
- [ ] Error handling paths

### Integration Tests Required

- [ ] End-to-end firmware deployment and testing
- [ ] Camera capture and processing pipeline
- [ ] MCP server communication reliability
- [ ] Timing and synchronization edge cases

### Hardware-in-Loop Tests Required

- [ ] Different lighting conditions
- [ ] Various e-ink content types (text, graphics, mixed)
- [ ] Partial vs full refresh scenarios
- [ ] Multiple consecutive tests (endurance)

## Documentation Requirements

### Developer Documentation

1. **Setup Guide**: Hardware configuration and software installation
2. **API Reference**: Complete function documentation
3. **Configuration Guide**: All settings and their effects
4. **Troubleshooting Guide**: Common issues and solutions

### User Documentation

1. **Quick Start**: Basic test writing and execution
2. **Test Patterns**: Examples for common scenarios
3. **Debugging Guide**: Interpreting heatmaps and test failures
4. **Best Practices**: Optimal test structure and organization

## Risk Assessment & Mitigation

### Architectural Risks (NEW - Based on MCP Evaluation)

1. **MCP Server Viability**
   - **Risk**: MCP servers may not meet performance/reliability requirements
   - **Likelihood**: Medium (untested in our specific use case)
   - **Impact**: High (would require architecture change)
   - **Mitigation**:
     - Phase 0 evaluation with clear go/no-go criteria
     - Alternative implementations ready (SSHex, Evision, Picam)
     - Hybrid approach if some MCPs work better than others
     - Maximum 1 week investment before decision point

2. **Performance Overhead**
   - **Risk**: MCP layer adds unacceptable latency (>2x slower than direct calls)
   - **Likelihood**: Medium (network/serialization overhead)
   - **Impact**: Medium (affects test execution speed)
   - **Mitigation**:
     - Benchmark against direct library calls
     - Identify critical path operations for optimization
     - Switch to direct libraries for performance-critical operations

3. **MCP Server Reliability**
   - **Risk**: Third-party MCP servers may be unstable or unmaintained
   - **Likelihood**: Medium (community projects, varying quality)
   - **Impact**: High (testing system unreliability)
   - **Mitigation**:
     - Evaluate multiple MCP server options for each function
     - Implement fallback mechanisms
     - Fork and maintain critical MCP servers if needed

### Phase 0 Contingency Plans

**If SSH MCP fails evaluation:**

- **Fallback**: Use SSHex library directly
- **Impact**: Lose Claude Code real-time SSH capabilities
- **Mitigation**: Claude Code generates SSH commands, human executes

**If Camera MCP fails evaluation:**

- **Fallback**: Use Picam library directly
- **Impact**: No real-time camera control from Claude Code
- **Mitigation**: Pre-configure camera, Claude Code triggers capture via file system

**If OpenCV MCP fails evaluation:**

- **Fallback**: Use Evision library directly  
- **Impact**: No real-time image processing from Claude Code
- **Mitigation**: Claude Code generates image processing pipelines, human reviews

**If all MCPs fail evaluation:**

- **Fallback**: Direct library implementation with Claude Code generating ExUnit tests
- **Impact**: No real-time interaction, but full automation still possible
- **Timeline**: Adds 0 weeks (alternative already planned)

### Technical Risks

1. **E-ink Timing Variability**
   - **Risk**: Inconsistent refresh timing causes false failures
   - **Mitigation**: Adaptive timing with multiple confirmation captures

2. **Environmental Sensitivity**
   - **Risk**: Lighting/positioning changes affect comparison accuracy
   - **Mitigation**: Controlled lighting setup + calibration procedures

3. **MCP Server Reliability**
   - **Risk**: Third-party MCP servers may be unstable
   - **Mitigation**: Fallback to direct library calls + monitoring

### Project Risks

1. **Hardware Setup Complexity**
   - **Risk**: Physical setup requirements may be difficult to replicate
   - **Mitigation**: Detailed setup documentation + reference hardware list

2. **Performance Requirements**
   - **Risk**: Test execution may be too slow for practical use
   - **Mitigation**: Parallel processing + optimized image operations

## Success Metrics

### Functional Metrics

- [ ] **Test Accuracy**: >95% correct pass/fail decisions
- [ ] **False Positive Rate**: <5% tests failing incorrectly
- [ ] **Coverage**: Test common e-ink use cases (text, UI, graphics)

### Performance Metrics

- [ ] **Test Speed**: <60 seconds per complete test cycle
- [ ] **Reliability**: >99% test completion rate
- [ ] **Resource Usage**: Within specified memory/CPU limits

### Usability Metrics

- [ ] **Setup Time**: <2 hours for new environment
- [ ] **Debug Efficiency**: Issue identification within 5 minutes of failure
- [ ] **Developer Adoption**: Successfully used by team members

---

## Implementation Notes

This PRD provides the foundation for implementing a comprehensive e-ink display testing system. The phased approach allows for iterative development while ensuring each component is thoroughly tested before moving to the next phase.

Key success factors:

1. **Start Simple**: Basic capture/compare before advanced features
2. **Validate Early**: Test with real hardware from day one
3. **Document Everything**: Setup procedures are critical for reproducibility
4. **Plan for Failure**: Robust error handling is essential for reliable testing

The hybrid approach of supporting both interactive development (Claude Code + MCPs) and automated testing (ExUnit) provides flexibility for different development workflows while maintaining the benefits of both approaches.
