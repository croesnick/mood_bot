# Backlog

This is my project backlog.

- Tasks are small and isolated things to be done.
- Stories are comprised of tasks, encapsulating a feature. They require a series of changes to be made to the codebase.
- Epics are comprised of stories, being broader in scope, requiring significant effort to complete.

The backlog is ordered descending by priority, so highest priority comes first.

## Task: Architecture display, driver, hal

What's the intended responsibilities of these three modules?
Currently, the displa initialized the hal.
Does this mean that driver and hal are co-located?
Or both the driver and display depend directly on the hal?
Because I thought, the dependency chain would be: display -> driver -> hal.

## Epic: Robot Face Scan & Bitmap Conversion

A camera is attached to the Raspberry Pi.
On toggle (to be defined how), the user can hold a drawn picture of a robot face into the camera.
The camera will capture the image, normalize (deskew, crop, gray-scale transform) it.
Then, the image will be pixelated and shown on the display.
If approved by the user (to be defined how; maybe via voice (STT)), the robot face will be stored on device.

## Epic: E-ink Display Integration Testing System

Develop an automated integration testing system for an Elixir + Nerves project that validates e-ink display output using camera-based verification. The system will use Model Context Protocol (MCP) servers for device control and image processing, with heatmap-based comparison to detect display differences.

Details: [see here](./.specs/e-ink-integration-test-setup.md)