defmodule Mix.Tasks.ProcessImage do
  @moduledoc """
  Mix task to process images for the e-ink display.

  Processes images through the complete e-ink display pipeline:
  load → monochrome → resize (128×296) → save as viewable format

  ## Usage

      mix process_image input.png output.png
      mix process_image photo.jpg preview.tiff

  ## Examples

      # Process a photo for display preview
      mix process_image ~/Photos/sunset.png preview.png

      # Convert and resize an image
      mix process_image image.tiff display_ready.png

  ## Supported Formats

  **Input:** PNG, BMP, TIFF, WebP, PBM
  **Output:** PNG, TIFF, JPG, WebP

  The output file will show exactly how the image will appear on the 128×296 e-ink display.
  """

  use Mix.Task

  @shortdoc "Process images for e-ink display (128×296, monochrome)"

  def run([input_path, output_path]) do
    Mix.Task.run("app.start")

    IO.puts("🔄 Processing: #{input_path} → #{output_path}")
    IO.puts("📐 Target dimensions: 128×296 (e-ink display)")
    IO.puts("🎨 Converting to monochrome...")

    # Determine output format based on file extension
    output_format =
      case Path.extname(output_path) |> String.downcase() do
        ".pbm" -> :pbm
        _other -> :preview
      end

    result =
      case output_format do
        :pbm ->
          IO.puts("💾 Saving as P4 PBM format for device deployment...")
          MoodBot.Images.ImageProcessor.process_and_save_pbm(input_path, output_path)

        :preview ->
          IO.puts("🖼️  Saving as preview image...")
          MoodBot.Images.ImageProcessor.process_and_save_for_inspection(input_path, output_path)
      end

    case result do
      :ok ->
        case output_format do
          :pbm ->
            IO.puts("✅ Success! P4 PBM file saved to: #{output_path}")
            IO.puts("📱 You can now deploy this file to your embedded device")
            IO.puts("🔍 You can also view #{output_path} in any image viewer")

          :preview ->
            IO.puts("✅ Success! Preview image saved to: #{output_path}")

            IO.puts(
              "🖼️  You can now view #{output_path} to see how it will look on the e-ink display"
            )
        end

      {:error, reason} ->
        IO.puts("❌ Error: #{reason}")
        System.halt(1)
    end
  end

  def run(_) do
    IO.puts("""
    📱 MoodBot E-ink Display Image Processor

    Usage:
      mix process_image <input> <output>

    Examples:
      # Create P4 PBM file for device deployment
      mix process_image photo.png mood.pbm

      # Create preview image for inspection
      mix process_image photo.png preview.png

    Supported input formats:  PNG, BMP, TIFF, WebP, JPG, JPEG, PBM

    Output formats:
      - .pbm  → P4 PBM format for device deployment (viewable in image viewers)
      - .png, .tiff, .jpg, .webp → Preview images for inspection

    The processed images are optimized for the 128×296 e-ink display (monochrome, dithered).
    """)
  end
end
