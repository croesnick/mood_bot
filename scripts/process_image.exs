#!/usr/bin/env elixir

# Image Processing Script for MoodBot E-ink Display
#
# This script processes images through the complete e-ink display pipeline:
# load → monochrome → resize (128×296) → save as viewable format
#
# Usage:
#   ./scripts/process_image.exs input.png output.png
#   ./scripts/process_image.exs input.png output.tiff
#   echo "input.png" | ./scripts/process_image.exs - output.png
#
# Supported input formats: PNG, BMP, TIFF, WebP, PBM
# Supported output formats: PNG, TIFF, JPG, WebP

defmodule ImageProcessor do
  @moduledoc """
  Command-line image processor for MoodBot e-ink display pipeline.
  """

  def main(args) do
    case args do
      [input_path, output_path] ->
        process_image(input_path, output_path)

      ["-", output_path] ->
        # Read from stdin
        input_path = IO.read(:stdio, :line) |> String.trim()
        process_image(input_path, output_path)

      [] ->
        show_usage()
        System.halt(1)

      _ ->
        IO.puts("Error: Invalid arguments")
        show_usage()
        System.halt(1)
    end
  end

  defp process_image(input_path, output_path) do
    IO.puts("🔄 Processing: #{input_path} → #{output_path}")
    IO.puts("📐 Target dimensions: 128x296 (e-ink display)")
    IO.puts("🎨 Converting to monochrome...")

    # Add the project's lib directory to the code path
    Code.append_path("_build/dev/lib/mood_bot/ebin")
    Code.append_path("_build/dev/lib/image/ebin")
    Code.append_path("_build/dev/lib/vix/ebin")

    # Ensure dependencies are loaded
    Application.ensure_all_started(:image)

    case MoodBot.Images.ImageProcessor.process_and_save_for_inspection(input_path, output_path) do
      :ok ->
        IO.puts("✅ Success! Processed image saved to: #{output_path}")
        IO.puts("🖼️ You can now view #{output_path} to see how it will look on the e-ink display")
        System.halt(0)

      {:error, reason} ->
        IO.puts("❌ Error: #{reason}")
        System.halt(1)
    end
  end

  defp show_usage do
    IO.puts("""
    📱 MoodBot E-ink Display Image Processor

    Processes images for the 128×296 e-ink display by converting to monochrome
    and resizing while maintaining aspect ratio.

    Usage:
      #{System.argv0()} <input> <output>
      echo "input.png" | #{System.argv0()} - <output>

    Examples:
      #{System.argv0()} photo.png preview.png
      #{System.argv0()} image.tiff display_ready.png
      echo "input.png" | #{System.argv0()} - output.png

    Supported input formats:  PNG, BMP, TIFF, WebP, PBM
    Supported output formats: PNG, TIFF, JPG, WebP

    The output file will show exactly how the image will appear on the e-ink display.
    """)
  end
end

# Run the script
ImageProcessor.main(System.argv())
