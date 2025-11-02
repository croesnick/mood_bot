# Complete E-ink Integration Testing Pipeline

## End-to-End Testing Pipeline (Happy Path)

### Phase 1: Firmware Deployment

```
┌──────────────┐
│  SSH MCP     │
│  Server      │
└──────┬───────┘
       │
       ├─► 1.1: Transfer firmware (.fw file) to Raspberry Pi
       │        via SCP/SFTP
       │        Target: /tmp/firmware.fw
       │
       └─► 1.2: Execute firmware update command
                Command: nerves_firmware.update()
                Wait for: Update completion + reboot
                Timeout: 60 seconds
```

### Phase 2: Display Test Trigger

```
┌──────────────┐
│  SSH MCP     │
│  Server      │
└──────┬───────┘
       │
       ├─► 2.1: Execute display test command via SSH
       │        Command: MoodBot.Controller.display_test()
       │        or: curl http://nerves.local/api/display/test
       │
       ├─► 2.2: Monitor display update start
       │        Check: Display refresh initiated
       │        Log: Capture test pattern ID/timestamp
       │
       └─► 2.3: Wait for e-ink refresh to complete
                Duration: 15-20 seconds (hardware limitation)
                Validation: Check display state = :stable
                Retry: Poll every 1s for status
```

### Phase 3: Image Capture

```
┌──────────────┐
│ Camera MCP   │
│ Server       │
└──────┬───────┘
       │
       ├─► 3.1: Configure camera settings
       │        Resolution: 1920x1080 (or 4K if available)
       │        Format: PNG (lossless)
       │        Focus: Auto-focus on e-ink display area
       │        Exposure: Auto (or 5000K-6500K white balance)
       │
       ├─► 3.2: Wait for display stabilization
       │        Additional delay: 500ms after refresh complete
       │        Reason: Ensure no residual pixel transitions
       │
       ├─► 3.3: Capture series of images
       │        Count: 3 images (for averaging/validation)
       │        Interval: 200ms between captures
       │        Naming: test_{timestamp}_{seq}.png
       │
       └─► 3.4: Transfer images to test orchestrator
                Method: File stream or base64 encoding
                Storage: /tmp/eink_test/captures/
                Metadata: Include timestamp, camera settings
```

### Phase 4: Image Preprocessing

```
┌──────────────┐
│ OpenCV MCP   │
│ Server       │
└──────┬───────┘
       │
       ├─► 4.1: Load raw camera images
       │        Input: 3 PNG files from Phase 3
       │        Format validation: Check resolution, color space
       │
       ├─► 4.2: Display area detection
       │        Algorithm: Edge detection (Canny)
       │        Find: 128x296 pixel display boundaries
       │        Output: Bounding box coordinates
       │
       ├─► 4.3: Crop to display area
       │        Input: Bounding box from 4.2
       │        Output: Cropped image containing only e-ink display
       │        Validation: Ensure crop includes full display
       │
       ├─► 4.4: Perspective correction
       │        Detect: Camera angle/skew (±15° rotation, ±10° skew)
       │        Transform: Perspective warp to orthogonal view
       │        Output: Straight-on view of display
       │
       ├─► 4.5: Resize to native resolution
       │        Target: Exactly 128x296 pixels
       │        Algorithm: High-quality bicubic interpolation
       │        Preserve: Aspect ratio and sharpness
       │
       ├─► 4.6: Lighting normalization
       │        Apply: Histogram equalization
       │        Adjust: Contrast and brightness uniformity
       │        Compensate: Uneven lighting across display
       │
       ├─► 4.7: Grayscale conversion
       │        Convert: RGB → Grayscale
       │        Method: Luminosity-based conversion
       │
       └─► 4.8: Noise reduction (minimal)
                Apply: Gaussian blur (0.5-1 pixel radius)
                Goal: Remove camera noise without losing detail
                Output: Preprocessed image ready for comparison
```

### Phase 5: Expected Image Generation

```
┌──────────────┐
│ Test         │
│ Orchestrator │
└──────┬───────┘
       │
       ├─► 5.1: Load test pattern definition
       │        Source: Test case specification
       │        Format: Expected content description
       │        Example: "Robot face - happy mood"
       │
       ├─► 5.2: Generate reference bitmap
       │        Method: Render same code used on device
       │        Resolution: 128x296 pixels
       │        Format: Monochrome (black/white)
       │
       └─► 5.3: Apply same preprocessing
                Steps: Same as Phase 4.7-4.8
                Goal: Ensure expected and actual are comparable
                Output: Reference image for comparison
```

### Phase 6: Heatmap-Based Comparison

```
┌──────────────┐
│ OpenCV MCP   │
│ Server       │
└──────┬───────┘
       │
       ├─► 6.1: Load images for comparison
       │        Input 1: Preprocessed actual image (Phase 4)
       │        Input 2: Reference image (Phase 5)
       │        Validation: Both 128x296 grayscale
       │
       ├─► 6.2: Pixel-level difference calculation
       │        Algorithm: Absolute difference per pixel
       │        Formula: diff[i,j] = |actual[i,j] - expected[i,j]|
       │        Output: Difference matrix (128x296)
       │
       ├─► 6.3: Calculate similarity metrics
       │        SSIM: Structural Similarity Index (overall score)
       │        Pixel Diff %: Percentage of pixels with >15 intensity diff
       │        MAE: Mean Absolute Error across all pixels
       │        Thresholds:
       │          - SSIM >0.95 = Pass
       │          - SSIM 0.90-0.95 = Warning
       │          - SSIM <0.90 = Fail
       │
       ├─► 6.4: Generate difference heatmap
       │        Color scheme:
       │          - Black: Perfect match (diff = 0)
       │          - Yellow: Minor difference (diff = 1-15)
       │          - Orange: Moderate difference (diff = 16-50)
       │          - Red: Major difference (diff >50)
       │        Resolution: 128x296 (native display)
       │        Output format: PNG with color overlay
       │
       ├─► 6.5: Region-based analysis (8x6 grid)
       │        Grid cell size: 16x37 pixels each
       │        Per-region metrics:
       │          - Region SSIM score
       │          - Max pixel difference
       │          - Average pixel difference
       │        Purpose: Identify localized issues
       │
       ├─► 6.6: Ghosting detection (if previous state available)
       │        Compare: Current image vs. previous display state
       │        Threshold: <3% similarity in non-updated regions
       │        Output: Ghosting artifact map
       │
       └─► 6.7: Generate visual comparison output
                Composite image layout:
                ┌────────┬────────┬────────┐
                │Expected│ Actual │Heatmap │
                └────────┴────────┴────────┘
                Include: Metrics overlay (SSIM, diff %)
                Save to: /tmp/eink_test/results/comparison_{timestamp}.png
```

### Phase 7: Test Result Evaluation

```
┌──────────────┐
│ Test         │
│ Orchestrator │
└──────┬───────┘
       │
       ├─► 7.1: Evaluate test outcome
       │        Pass criteria:
       │          - SSIM >0.95
       │          - Pixel diff <2%
       │          - No critical regions failing
       │          - No excessive ghosting
       │        Fail criteria:
       │          - SSIM <0.90
       │          - Pixel diff >5%
       │          - Critical regions unreadable
       │
       ├─► 7.2: Generate test report
       │        Include:
       │          - Test metadata (timestamp, firmware version)
       │          - Similarity metrics
       │          - Pass/fail status
       │          - Heatmap visualization
       │          - Failed region details (if any)
       │          - Recommendations for failures
       │
       └─► 7.3: Archive test artifacts
                Store:
                  - Raw camera images
                  - Preprocessed images
                  - Reference image
                  - Heatmap visualization
                  - Test report (JSON + human-readable)
                Location: /tmp/eink_test/archive/{test_id}/
                Retention: Configurable (default: 30 days)
```

---

## Visual Pipeline Boxes Summary

For diagram creation, here are the key boxes and connections:

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  SSH MCP    │────>│  SSH MCP    │────>│ Camera MCP  │
│  Deploy FW  │     │ Trigger Test│     │Capture Image│
└─────────────┘     └─────────────┘     └─────────────┘
                                              │
                                              v
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│ OpenCV MCP  │<────│  OpenCV MCP │<────│  OpenCV MCP │
│  Heatmap +  │     │  Normalize  │     │Detect & Crop│
│  Compare    │     │  & Convert  │     │   Display   │
└─────────────┘     └─────────────┘     └─────────────┘
      │
      v
┌─────────────┐
│   Report    │
│  Pass/Fail  │
│  + Metrics  │
└─────────────┘
```

### Key Data Flows Between Boxes

1. **SSH MCP → Raspberry Pi**: `.fw` firmware file
2. **SSH MCP → Raspberry Pi**: Test trigger command
3. **Raspberry Pi → E-ink Display**: Display update (15-20s refresh)
4. **Camera MCP → OpenCV MCP**: 3× PNG images (1920x1080+)
5. **OpenCV MCP**: Crop → Perspective correct → Resize to 128×296 → Normalize → Grayscale
6. **OpenCV MCP**: Compare actual vs. expected → Generate heatmap
7. **OpenCV MCP → Test Report**: SSIM score, diff %, heatmap PNG, pass/fail

---

## Detailed Pipeline Flow

### Complete Sequential Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ 1. SSH MCP: Deploy Firmware                                     │
│    → Transfer .fw file via SCP                                  │
│    → Execute nerves_firmware.update()                           │
│    → Wait for reboot (60s timeout)                              │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ 2. SSH MCP: Trigger Display Test                                │
│    → Execute MoodBot.Controller.display_test()                  │
│    → Monitor refresh initiation                                 │
│    → Wait for e-ink refresh complete (15-20s)                   │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ 3. Camera MCP: Capture Images                                   │
│    → Configure camera (1080p/4K PNG)                            │
│    → Wait 500ms stabilization                                   │
│    → Capture 3 images (200ms interval)                          │
│    → Transfer to /tmp/eink_test/captures/                       │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ 4. OpenCV MCP: Preprocess Images                                │
│    → Load 3 PNG files                                           │
│    → Edge detection → Find 128x296 display                      │
│    → Crop to display area                                       │
│    → Perspective correction (±15° rotation, ±10° skew)          │
│    → Resize to 128x296                                          │
│    → Normalize lighting (histogram equalization)                │
│    → Convert to grayscale                                       │
│    → Apply noise reduction (0.5-1px Gaussian blur)              │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ 5. Test Orchestrator: Generate Expected Image                   │
│    → Load test pattern definition                               │
│    → Render reference bitmap (128x296)                          │
│    → Apply same preprocessing (grayscale + noise reduction)     │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ 6. OpenCV MCP: Heatmap Comparison                               │
│    → Load actual (Phase 4) and expected (Phase 5)               │
│    → Calculate pixel-level difference matrix                    │
│    → Compute SSIM, pixel diff %, MAE metrics                    │
│    → Generate color heatmap (black/yellow/orange/red)           │
│    → Perform 8x6 grid region analysis                           │
│    → Detect ghosting artifacts (if previous state available)    │
│    → Create composite visualization (Expected|Actual|Heatmap)   │
└─────────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────────┐
│ 7. Test Orchestrator: Evaluate & Report                         │
│    → Evaluate pass/fail (SSIM >0.95, diff <2%)                  │
│    → Generate test report (JSON + human-readable)               │
│    → Archive all artifacts to /tmp/eink_test/archive/{test_id}/ │
│    → Return result to test runner                               │
└─────────────────────────────────────────────────────────────────┘
```

### Performance Targets

- **Total Test Duration**: <45 seconds per test case
- **Image Capture**: <2 seconds from trigger
- **Image Processing**: <2 seconds for full pipeline
- **E-ink Refresh Wait**: 15-20 seconds (hardware limitation)
- **Comparison Analysis**: <1 second for heatmap generation

### Resource Requirements

- **Memory Usage**: <128MB peak during image processing
- **Disk Space**: <50MB for test artifacts per run
- **CPU Usage**: <60% during processing bursts
- **Network**: <5MB transfer per test
