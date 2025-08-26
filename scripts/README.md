# Image Processing Scripts

This directory contains scripts for processing images through the MoodBot e-ink display pipeline.

## Overview

The image processing pipeline converts any image to the format required by the 128×296 e-ink display:

1. **Load** - Support for PNG, BMP, TIFF, WebP, PBM formats
2. **Monochrome** - Convert to 1-bit black/white using dithering
3. **Resize** - Scale to 128×296 maintaining aspect ratio
4. **Save** - Output as viewable BMP/TIFF/PNG for inspection

## Scripts

### process_image.exs

Standalone Elixir script for command-line image processing.

```bash
# Make executable (first time only)
chmod +x scripts/process_image.exs

# Process an image
./scripts/process_image.exs input.png output.bmp
./scripts/process_image.exs photo.jpg preview.tiff

# Pipe from stdin
echo "input.png" | ./scripts/process_image.exs - output.bmp
```

### Mix Task

Use the built-in Mix task for easier project integration:

```bash
# Process images using Mix
mix process_image input.png output.bmp
mix process_image photo.jpg preview.tiff

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

## Examples

```bash
# Convert a photo to see how it looks on e-ink
mix process_image ~/Photos/sunset.jpg eink_preview.png

# Process a PNG and save as TIFF
./scripts/process_image.exs logo.png display_logo.tiff

# Batch process with shell
for img in *.png; do
  mix process_image "$img" "processed_${img%.*}.png"
done
```

## Programming Interface

You can also use the functions directly in Elixir code:

```elixir
# Complete pipeline: load → monochrome → resize → save
MoodBot.Images.Bitmap.process_and_save_for_inspection("input.png", "output.png")

# Create display preview
MoodBot.Images.Bitmap.create_display_preview("photo.jpg", "preview.png")

# Individual steps
{:ok, image} = MoodBot.Images.Bitmap.load_image("input.png")
{:ok, mono} = MoodBot.Images.Bitmap.convert_to_monochrome(image)  
{:ok, resized} = MoodBot.Images.Bitmap.resize_to_display(mono)
:ok = MoodBot.Images.Bitmap.save_processed_image(resized, "output.png")

# For actual display use
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