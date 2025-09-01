# Image Processing Scripts

This directory contains scripts for processing images through the MoodBot e-ink display pipeline.

## Overview

The image processing pipeline converts any image to the format required by the 128×296 e-ink display:

1. **Load** - Support for PNG, BMP, TIFF, WebP, PBM formats
2. **Monochrome** - Convert with mode options (binary or grayscale)
3. **Resize** - Scale to 128×296 maintaining aspect ratio
4. **Save** - Output as viewable BMP/TIFF/PNG for inspection

## Scripts

### process_image.exs

Standalone Elixir script for command-line image processing with mode options.

```bash
# Make executable (first time only)
chmod +x scripts/process_image.exs

# Process with default binary mode (optimized for e-ink)
./scripts/process_image.exs input.png output.bmp
./scripts/process_image.exs photo.jpg preview.tiff

# Explicit mode selection
./scripts/process_image.exs input.png output.png --mode bw        # Binary mode
./scripts/process_image.exs input.png output.png --mode grayscale # Grayscale mode

# Pipe from stdin with mode
echo "input.png" | ./scripts/process_image.exs - output.bmp --mode bw

# Help
./scripts/process_image.exs --help
```

### Mix Task

Use the built-in Mix task for easier project integration:

```bash
# Process images using Mix with mode options
mix process_image input.png output.bmp                    # Default binary mode
mix process_image input.png output.png --mode bw          # Explicit binary mode
mix process_image photo.jpg preview.tiff --mode grayscale # Grayscale mode

# Get help
mix help process_image
```

## Supported Formats

**Input Formats:**
- PNG - Portable Network Graphics
- BMP - Windows Bitmap  
- TIFF - Tagged Image File Format
- WebP - Google WebP format
- PBM - Portable Bitmap (P1/P4)

**Output Formats:**
- PNG - Portable Network Graphics (recommended for inspection)
- TIFF - Tagged Image File Format  
- JPEG/JPG - JPEG format
- WebP - Google WebP format

## Conversion Modes

- **`bw` (default)**: True black/white conversion using threshold-based processing
  - Pixels are converted to pure black (0) or white (255) only
  - Optimized for e-ink displays which work best with binary images
  - Provides crisp, high-contrast output ideal for text and graphics

- **`grayscale`**: Traditional grayscale conversion
  - Preserves multiple gray levels (0-255)
  - Useful for preview/inspection purposes
  - Better for photographic content when grayscale detail is desired

## Examples

```bash
# Convert a photo for e-ink deployment (binary mode)
mix process_image ~/Photos/sunset.jpg eink_preview.png --mode bw

# Preview in grayscale to see detail preservation
mix process_image ~/Photos/sunset.jpg grayscale_preview.png --mode grayscale

# Process a PNG logo for display
./scripts/process_image.exs logo.png display_logo.tiff --mode bw

# Batch process with different modes
for img in *.png; do
  # Create binary version for e-ink
  mix process_image "$img" "binary_${img%.*}.png" --mode bw
  # Create grayscale version for preview
  mix process_image "$img" "gray_${img%.*}.png" --mode grayscale
done
```

## Programming Interface

You can also use the functions directly in Elixir code with mode support:

```elixir
# Complete pipeline with mode options
MoodBot.Images.ImageProcessor.process_and_save_for_inspection("input.png", "output.png", :bw)
MoodBot.Images.ImageProcessor.process_and_save_for_inspection("input.png", "output.png", :grayscale)

# Create display preview with mode
MoodBot.Images.ImageProcessor.create_display_preview("photo.jpg", "preview.png", :bw)

# Process for actual display
{:ok, binary_data} = MoodBot.Images.ImageProcessor.process_for_display("input.png", :bw)
MoodBot.Display.display_image(binary_data)

# Legacy bitmap functions (still available)
{:ok, display_data} = MoodBot.Images.Bitmap.load_for_display("input.png")
MoodBot.Display.display_image(display_data)
```

## Output

The processed images will show exactly how they will appear on the 128×296 e-ink display:
- **Black pixels** represent ink (dark areas)  
- **White pixels** represent no ink (light areas)
- **Dimensions** are exactly 128×296 pixels
- **Aspect ratio** is preserved with white padding if needed

## Performance

The image processing uses the high-performance Image library with libvips backend:
- 2-3x faster than ImageMagick-based alternatives
- 5x less memory usage  
- Optimized for batch processing
- Hardware-accelerated operations where available