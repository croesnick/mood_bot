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
    case parse_args(args) do
      {:ok, input_path, output_path, mode} ->
        process_image(input_path, output_path, mode)

      {:stdin, output_path, mode} ->
        # Read from stdin
        input_path = IO.read(:stdio, :line) |> String.trim()
        process_image(input_path, output_path, mode)

      :help ->
        show_usage()
        System.halt(0)

      :error ->
        IO.puts("Error: Invalid arguments")
        show_usage()
        System.halt(1)
    end
  end

  defp process_image(input_path, output_path, mode) do
    mode_description = case mode do
      :bw -> "true black/white (e-ink optimized)"
      :grayscale -> "grayscale (preview mode)"
    end
    
    IO.puts("🔄 Processing: #{input_path} → #{output_path}")
    IO.puts("📐 Target dimensions: 128x296 (e-ink display)")
    IO.puts("🎨 Converting to #{mode_description}...")

    # Add the project's lib directory to the code path
    Code.append_path("_build/dev/lib/mood_bot/ebin")
    Code.append_path("_build/dev/lib/image/ebin")
    Code.append_path("_build/dev/lib/vix/ebin")

    # Ensure dependencies are loaded
    Application.ensure_all_started(:image)

    case MoodBot.Images.ImageProcessor.process_and_save_for_inspection(input_path, output_path, mode) do
      :ok ->
        IO.puts("✅ Success! Processed image saved to: #{output_path}")
        IO.puts("🖼️ You can now view #{output_path} to see how it will look on the e-ink display")
        IO.puts("⚙️ Mode: #{mode_description}")
        System.halt(0)

      {:error, reason} ->
        IO.puts("❌ Error: #{reason}")
        System.halt(1)
    end
  end

  defp parse_args(args) do
    case args do
      [] -> :help
      ["-h"] -> :help
      ["--help"] -> :help
      
      [input_path, output_path] ->
        {:ok, input_path, output_path, :bw}
        
      [input_path, output_path, "--mode", mode_str] ->
        case parse_mode(mode_str) do
          {:ok, mode} -> {:ok, input_path, output_path, mode}
          :error -> :error
        end
        
      ["-", output_path] ->
        {:stdin, output_path, :bw}
        
      ["-", output_path, "--mode", mode_str] ->
        case parse_mode(mode_str) do
          {:ok, mode} -> {:stdin, output_path, mode}
          :error -> :error
        end
        
      _ -> :error
    end
  end
  
  defp parse_mode(mode_str) do
    case String.downcase(mode_str) do
      "bw" -> {:ok, :bw}
      "grayscale" -> {:ok, :grayscale}
      "gray" -> {:ok, :grayscale}
      _ -> :error
    end
  end

  defp show_usage do
    IO.puts("""
    📱 MoodBot E-ink Display Image Processor

    Processes images for the 128×296 e-ink display with conversion mode options.

    Usage:
      ./scripts/process_image.exs <input> <output> [--mode <mode>]
      echo "input.png" | ./scripts/process_image.exs - <output> [--mode <mode>]
      ./scripts/process_image.exs -h | --help

    Modes:
      bw        True black/white conversion (default) - optimized for e-ink display
      grayscale Grayscale conversion - useful for preview/inspection

    Examples:
      ./scripts/process_image.exs photo.png preview.png
      ./scripts/process_image.exs photo.png preview.png --mode bw
      ./scripts/process_image.exs image.tiff preview.png --mode grayscale
      echo "input.png" | ./scripts/process_image.exs - output.png --mode bw

    Supported input formats:  PNG, BMP, TIFF, WebP, PBM
    Supported output formats: PNG, TIFF, JPG, WebP

    The output file will show exactly how the image will appear on the e-ink display.
    Use --mode bw (default) for e-ink deployment, --mode grayscale for previewing.
    """)
  end
end

# Run the script
ImageProcessor.main(System.argv())
